-- Fix: admin_export_users / admin_export_orders returned no rows.
--
-- العطل: داخل دالة plpgsql كان الـ SELECT النهائي مجردًا (bare SELECT) بلا
-- RETURN QUERY، فالـ plpgsql لا يملك وجهة لنتيجة الاستعلام ويرفع
-- «query has no destination for result data» بدل إرجاع الصفوف — أي أن تصدير
-- المستخدمين/الطلبات من لوحة الإدارة كان يفشل كليًا.
-- الإصلاح: إسناد النتيجة إلى RETURN QUERY في الدالتين.
--
-- نص الدالتين أدناه هو التعريف الحيّ كما هو (pg_get_functiondef) بعد الإصلاح،
-- وليس إعادة كتابة يدوية. لا يُعاد تطبيقه من هنا تلقائيًا.

CREATE OR REPLACE FUNCTION public.admin_export_users(p_search text DEFAULT NULL::text, p_role text DEFAULT NULL::text)
 RETURNS TABLE(user_id uuid, full_name text, phone_number text, email text, national_id text, role text, workshop_name text, is_online boolean, phone_verified boolean, banned boolean, orders_as_owner integer, orders_as_provider integer, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_digits text;
  v_role   public.user_role;
  v_marked bigint;
begin
  perform public.assert_admin();

  if v_search is not null then
    v_digits := nullif(regexp_replace(v_search, '\D', '', 'g'), '');
  end if;

  v_role := case
    when coalesce(p_role, '') in ('car_owner', 'provider')
    then p_role::public.user_role
  end;

  return query
  with base as (
    select
      pr.id                                   as uid,
      pr.full_name,
      pr.phone_number,
      pr.email,
      pr.national_id,
      pr.role::text                           as role_text,
      pw.workshop_name,
      pw.is_online,
      (pr.phone_verified_at is not null)      as phone_verified,
      (au.banned_until is not null and au.banned_until > now()) as banned,
      pr.created_at,
      count(*) over ()                        as total
    from public.profiles pr
    left join public.providers pw on pw.id = pr.id
    left join auth.users au       on au.id  = pr.id
    where (v_role is null or pr.role = v_role)
      and (
        v_search is null
        or pr.full_name  ilike '%' || v_search || '%'
        or pr.email      ilike '%' || v_search || '%'
        or pw.workshop_name ilike '%' || v_search || '%'
        or (v_digits is not null
            and (regexp_replace(pr.phone_number, '\D', '', 'g') like '%' || v_digits || '%'
                 or (pr.national_id is not null
                     and translate(pr.national_id,
                           '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'::text,
                           '01234567890123456789'::text)
                          like '%' || v_digits || '%')))
      )
  )
  select
    b.uid,
    b.full_name,
    b.phone_number,
    b.email,
    b.national_id,
    b.role_text,
    b.workshop_name,
    b.is_online,
    b.phone_verified,
    b.banned,
    coalesce((select count(*) from public.orders o where o.car_owner_id = b.uid), 0)::int,
    coalesce((select count(*) from public.orders o where o.provider_id = b.uid), 0)::int,
    b.created_at
  from base b
  order by b.created_at desc
  limit 5000;

  get diagnostics v_marked = row_count;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (
    auth.uid(),
    'export_users',
    null,
    jsonb_build_object(
      'rows_returned', v_marked,
      'search',        v_search,
      'role',          p_role
    )
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_export_orders(p_status text DEFAULT NULL::text, p_search text DEFAULT NULL::text)
 RETURNS TABLE(id uuid, service text, status text, offered_price numeric, currency text, owner_name text, provider_name text, owner_phone text, car_title text, address_text text, eta_minutes integer, notes text, provider_notes text, attachments_count integer, provider_attachments_count integer, share_phone boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_status public.order_status;
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_marked bigint;
begin
  perform public.assert_admin();

  v_status := case
    when coalesce(p_status, '') in
      ('pending','priced','confirmed','rejected_by_provider','rejected_by_owner','cancelled','completed')
    then p_status::public.order_status
  end;

  return query
  with base as (
    select
      o.id,
      st.name_ar                              as service,
      o.status::text                          as status_text,
      o.offered_price,
      o.currency,
      coalesce(owner_p.full_name, owner_au.email)   as owner_name,
      coalesce(provider_p.full_name, provider_au.email) as provider_name,
      o.owner_phone,
      nullif(trim(concat(o.car_make, ' ', o.car_model, ' ', coalesce(o.car_year::text, ''))), '') as car_title,
      o.address_text,
      o.eta_minutes,
      o.notes,
      o.provider_notes,
      coalesce(array_length(o.attachments::text[], 1), 0)::int          as attachments_count,
      coalesce(array_length(o.provider_attachments::text[], 1), 0)::int as provider_attachments_count,
      o.share_phone,
      o.created_at,
      o.updated_at
    from (
      select o.*, row_number() over (order by o.created_at desc) as rn
      from public.orders o
    ) o
    left join public.service_types st      on st.id = o.service_type_id
    left join public.profiles owner_p      on owner_p.id = o.car_owner_id
    left join auth.users    owner_au       on owner_au.id = o.car_owner_id
    left join public.profiles provider_p  on provider_p.id = o.provider_id
    left join auth.users    provider_au    on provider_au.id = o.provider_id
    where (v_status is null or o.status = v_status)
      and (
        v_search is null
        or o.address_text ilike '%' || v_search || '%'
        or o.notes        ilike '%' || v_search || '%'
        or coalesce(owner_p.full_name, owner_au.email)  ilike '%' || v_search || '%'
        or coalesce(provider_p.full_name, provider_au.email) ilike '%' || v_search || '%'
        or st.name_ar ilike '%' || v_search || '%'
        or o.owner_phone ilike '%' || v_search || '%'
      )
      and o.rn <= 5000
  )
  select
    b.id, b.service, b.status_text, b.offered_price, b.currency,
    b.owner_name, b.provider_name, b.owner_phone, b.car_title,
    b.address_text, b.eta_minutes, b.notes, b.provider_notes,
    b.attachments_count, b.provider_attachments_count, b.share_phone,
    b.created_at, b.updated_at
  from base b
  order by b.created_at desc;

  get diagnostics v_marked = row_count;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (
    auth.uid(),
    'export_orders',
    null,
    jsonb_build_object(
      'rows_returned', v_marked,
      'status',        p_status,
      'search',        v_search
    )
  );
end;
$function$
;
