-- =============================================================================
-- Phase 5A follow-up (Yousef decision, 2026-10-17): he is the sole dashboard
-- viewer, so the national ID must be UNMASKED everywhere (list / detail /
-- export). min signed audit stays ON for exports. admin_reveal_national_id
-- remains available and still writes to admin_audit_log.
--
-- Rebuilds the three read RPCs (same guards: assert_admin, security definer,
-- search_path='', revoked from public/anon):
--   * admin_list_users(int, int, text, text)  -> national_id (full)
--   * admin_get_user(uuid)                    -> profile.national_id (full)
--   * admin_export_users(text, text)          -> national_id (full)
-- =============================================================================

drop function if exists public.admin_list_users(int, int, text, text);
drop function if exists public.admin_export_users(text, text);
drop function if exists public.admin_get_user(uuid);

-- ---------------------------------------------------------------------------
create or replace function public.admin_list_users(
  p_page      int  default 1,
  p_page_size int  default 25,
  p_search    text default null,
  p_role      text default null
)
returns table (
  user_id            uuid,
  full_name          text,
  phone_number       text,
  email              text,
  role               text,
  workshop_name      text,
  is_online          boolean,
  phone_verified     boolean,
  national_id        text,
  orders_as_owner    int,
  orders_as_provider int,
  created_at         timestamptz,
  total_count        bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_page   int := greatest(coalesce(p_page, 1), 1);
  v_size   int := least(greatest(coalesce(p_page_size, 25), 1), 100);
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_digits text;
  v_role   public.user_role;
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
      pr.role::text                           as role_text,
      pw.workshop_name,
      pw.is_online,
      (pr.phone_verified_at is not null)      as phone_verified,
      pr.national_id,
      pr.created_at,
      count(*) over ()                        as total
    from public.profiles pr
    left join public.providers pw on pw.id = pr.id
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
    b.role_text,
    b.workshop_name,
    b.is_online,
    b.phone_verified,
    b.national_id,
    coalesce((select count(*) from public.orders o where o.car_owner_id = b.uid), 0)::int,
    coalesce((select count(*) from public.orders o where o.provider_id = b.uid), 0)::int,
    b.created_at,
    b.total
  from base b
  order by b.created_at desc, b.uid
  limit v_size
  offset (v_page - 1) * v_size;
end;
$$;

revoke all on function public.admin_list_users(int, int, text, text) from public;
revoke all on function public.admin_list_users(int, int, text, text) from anon;
grant execute on function public.admin_list_users(int, int, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
create or replace function public.admin_get_user(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.assert_admin();

  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'USER_NOT_FOUND';
  end if;

  return jsonb_build_object(
    'profile', (
      select jsonb_build_object(
        'id',              pr.id,
        'full_name',       pr.full_name,
        'phone_number',    pr.phone_number,
        'email',           pr.email,
        'national_id',     pr.national_id,
        'role',            pr.role::text,
        'language',        pr.language,
        'avatar_id',       pr.avatar_id,
        'created_at',      pr.created_at,
        'updated_at',      pr.updated_at,
        'phone_verified_at', pr.phone_verified_at
      )
      from public.profiles pr where pr.id = p_user_id
    ),
    'auth', (
      select jsonb_build_object(
        'email',         u.email,
        'last_sign_in_at', u.last_sign_in_at,
        'created_at',    u.created_at,
        'banned_until',  u.banned_until
      )
      from auth.users u where u.id = p_user_id
    ),
    'cars', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id, 'make', c.make, 'model', c.model, 'year', c.year,
        'plate_number', c.plate_number, 'color', c.color, 'created_at', c.created_at
      )), '[]'::jsonb)
      from public.car_details c where c.user_id = p_user_id
    ),
    'provider', (
      select
        case when count(*) = 0 then null else jsonb_build_object(
          'workshop_name',    max(pw.workshop_name),
          'address',          max(pw.address),
          'latitude',         max(pw.latitude),
          'longitude',        max(pw.longitude),
          'support_scope',    max(pw.support_scope::text),
          'has_vehicle',      max(pw.has_vehicle),
          'vehicle_specs',    max(pw.vehicle_specs),
          'is_online',        max(pw.is_online),
          'location_updated_at', max(pw.location_updated_at),
          'created_at',       max(pw.created_at)
        ) end
      from public.providers pw where pw.id = p_user_id
    ),
    'specializations', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', st.id, 'name_ar', st.name_ar, 'name_en', st.name_en
      )), '[]'::jsonb)
      from public.provider_specializations ps
      join public.service_types st on st.id = ps.service_type_id
      where ps.provider_id = p_user_id
    ),
    'orders_as_owner', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id, 'status', o.status::text,
        'service_type', st.name_ar,
        'offered_price', o.offered_price,
        'created_at', o.created_at, 'updated_at', o.updated_at
      )), '[]'::jsonb)
      from (
        select o.*, row_number() over (order by o.created_at desc) as rn
        from public.orders o where o.car_owner_id = p_user_id
      ) o
      left join public.service_types st on st.id = o.service_type_id
      where o.rn <= 20
    ),
    'orders_as_provider', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id, 'status', o.status::text,
        'service_type', st.name_ar,
        'offered_price', o.offered_price,
        'created_at', o.created_at, 'updated_at', o.updated_at
      )), '[]'::jsonb)
      from (
        select o.*, row_number() over (order by o.created_at desc) as rn
        from public.orders o where o.provider_id = p_user_id
      ) o
      left join public.service_types st on st.id = o.service_type_id
      where o.rn <= 20
    ),
    'ratings_received', (
      select jsonb_build_object(
        'avg', round(avg(rating)::numeric, 2),
        'count', count(*)
      )
      from public.ratings where provider_id = p_user_id
    ),
    'ratings_given', (
      select jsonb_build_object(
        'avg', round(avg(rating)::numeric, 2),
        'count', count(*)
      )
      from public.ratings where user_id = p_user_id
    ),
    'notifications_count', (
      select count(*) from public.notifications where user_id = p_user_id
    ),
    'sms_recent', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'phone_local', s.phone_local, 'result', s.result,
        'created_at', s.created_at
      )), '[]'::jsonb)
      from (
        select s.*, row_number() over (order by s.created_at desc) as rn
        from public.sms_send_logs s where s.user_id = p_user_id
      ) s
      where s.rn <= 10
    ),
    'audit_entries', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', a.id, 'action', a.action, 'details', a.details,
        'created_at', a.created_at,
        'admin_name', pr.full_name
      ) order by a.created_at desc), '[]'::jsonb)
      from (
        select a.*, row_number() over (order by a.created_at desc) as rn
        from public.admin_audit_log a where a.target_user_id = p_user_id
      ) a
      left join public.profiles pr on pr.id = a.admin_id
      where a.rn <= 25
    )
  );
end;
$$;

revoke all on function public.admin_get_user(uuid) from public;
revoke all on function public.admin_get_user(uuid) from anon;
grant execute on function public.admin_get_user(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
create or replace function public.admin_export_users(
  p_search text default null,
  p_role   text default null
)
returns table (
  full_name          text,
  phone_number       text,
  email              text,
  national_id        text,
  role               text,
  workshop_name      text,
  is_online          boolean,
  phone_verified     boolean,
  orders_as_owner    int,
  orders_as_provider int,
  created_at         timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
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
      pr.created_at,
      count(*) over ()                        as total
    from public.profiles pr
    left join public.providers pw on pw.id = pr.id
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
    b.full_name,
    b.phone_number,
    b.email,
    b.national_id,
    b.role_text,
    b.workshop_name,
    b.is_online,
    b.phone_verified,
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
    'export_users_csv',
    null,
    jsonb_build_object(
      'rows_returned', v_marked,
      'search',        v_search,
      'role',          p_role
    )
  );
end;
$$;

revoke all on function public.admin_export_users(text, text) from public;
revoke all on function public.admin_export_users(text, text) from anon;
grant execute on function public.admin_export_users(text, text) to authenticated, service_role;