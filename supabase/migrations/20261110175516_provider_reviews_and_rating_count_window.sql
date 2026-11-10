-- =============================================================================
-- تقييمات بلا حجب + متوسط مقيّد بنافذة 30 يومًا لكل زوج (عميل ← مزود)
-- وقائمة آراء المزود العامة + عدد الطلبات المكتملة + عدّ العملاء المختلفين للأدمن.
--
-- Threat model / السبب:
--   * سابقًا يدخل كل تقييم في المتوسط فورًا، فيستطيع مزوّد و«عميل» متعاونان
--     رفع متوسط التقييم بطلبات صورية متكررة. القرار: يظل كل تقييم مسجّلًا
--     ولا يُرفض أبدًا، لكن متوسط التقييم يحتسب من صف يحمل counted_in_average.
--   * الإيجابي (3..5) يحتسب مرة واحدة كل 30 يومًا متحركة من آخر إيجابي محسوب
--     لنفس الزوج (provider_id, user_id). السلبي (1..2) يحتسب فورًا دائمًا.
--   * المتوسط والعدد المعروضان يأتيان من الـ view public_provider_profiles
--     (المصدر الوحيد لـ get_provider_details و get_nearest_providers) فلذلك
--     تُعاد كتابتها لتقرأ الصفوف المحسوبة فقط.
--   * آراء المزود العامة كانت محجوبة لأن RLS على ratings تسمح للطرفين فقط،
--     فتُفتح عبر SECURITY DEFINER يُرجع الاسم الثنائي وavatar فقط — بلا رقم
--     هاتف ولا national_id ولا id ولا بقية أجزاء الاسم.
-- =============================================================================

-- 1) علم احتساب الصف في المتوسط (افتراضيًا صحيح ثم يُعاد حسابه بالـ backfill).
alter table public.ratings
  add column if not exists counted_in_average boolean not null default true;

comment on column public.ratings.counted_in_average is
  'هل يدخل هذا التقييم في متوسط المزود؟ الإيجابي مرة كل 30 يومًا لكل زوج (مزود، عميل)، والسلبي دائمًا.';

-- 2) Backfill زمني: أول إيجابي محسوب، ثم كل إيجابي يبعد 30 يومًا على الأقل عن
--    آخر إيجابي *محسوب* (الإيجابي غير المحسوب لا يُحرّك النافذة). السلبي دائمًا.
do $$
declare
  r record;
  v_provider uuid;
  v_user uuid;
  v_last_counted timestamptz;
  v_counted boolean;
  v_same_pair boolean;
begin
  update public.ratings set counted_in_average = false;

  v_provider := null;
  v_user := null;

  for r in
    select id, provider_id, user_id, rating, created_at
    from public.ratings
    order by provider_id, user_id, created_at, id
  loop
    v_same_pair := (v_provider is not distinct from r.provider_id)
                   and (v_user is not distinct from r.user_id);
    if not v_same_pair then
      v_provider := r.provider_id;
      v_user := r.user_id;
      v_last_counted := null;
    end if;

    if r.rating <= 2 then
      v_counted := true;
    else
      v_counted := v_last_counted is null
                   or r.created_at >= v_last_counted + interval '30 days';
      if v_counted then
        v_last_counted := r.created_at;
      end if;
    end if;

    if v_counted then
      update public.ratings set counted_in_average = true where id = r.id;
    end if;
  end loop;
end $$;

-- فهرس البحث عن آخر إيجابي محسوب لنفس الزوج.
create index if not exists ratings_counted_positive_pair_idx
  on public.ratings (provider_id, user_id, created_at desc)
  where counted_in_average and rating >= 3;

-- 3) rate_provider: كل تقييم يُسجَّل بلا رفض، ويُحدَّد احتسابه داخل الدالة.
--    ALREADY_RATED يبقى فقط لمنع تكرار تقييم *نفس الطلب* (تكامل بيانات).
--    القفل الاستشاري يمنع تقييمين متزامنين لنفس الزوج من تجاوز النافذة.
create or replace function public.rate_provider(
  p_order_id uuid,
  p_rating integer,
  p_comment text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_service text;
  v_car_owner uuid;
  v_is_completed boolean;
  v_already_rated boolean;
  v_counted boolean;
  v_last_counted timestamptz;
begin
  select provider_id, service_type_id, car_owner_id into v_provider, v_service, v_car_owner
  from public.orders where id = p_order_id;

  if v_car_owner is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if auth.uid() is null or v_car_owner is distinct from auth.uid() then
    raise exception 'NOT_OWNER';
  end if;
  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'INVALID_RATING';
  end if;

  select status = 'completed' into v_is_completed from public.orders where id = p_order_id;
  if v_is_completed is not true then
    raise exception 'ORDER_NOT_COMPLETED';
  end if;

  select exists(select 1 from public.ratings where order_id = p_order_id) into v_already_rated;
  if v_already_rated then
    raise exception 'ALREADY_RATED';
  end if;

  -- قفل معاملات لكل زوج (مزود، عميل).
  perform pg_advisory_xact_lock(
    hashtextextended(v_provider::text || ':' || v_car_owner::text, 0)
  );

  if p_rating <= 2 then
    v_counted := true;
  else
    select max(created_at) into v_last_counted
    from public.ratings
    where provider_id = v_provider
      and user_id = v_car_owner
      and counted_in_average
      and rating >= 3;

    v_counted := v_last_counted is null
                 or now() >= v_last_counted + interval '30 days';
  end if;

  insert into public.ratings (order_id, provider_id, user_id, rating, comment, counted_in_average)
  values (p_order_id, v_provider, v_car_owner, p_rating, p_comment, v_counted);

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_provider,
    p_order_id,
    'rating_received',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service),
      'rating', p_rating
    )
  );
end;
$$;

-- 4) الـ view: المتوسط والعدد من الصفوف المحسوبة فقط (بنفس الأعمدة والترتيب).
create or replace view public.public_provider_profiles as
 SELECT pr.id AS provider_id,
    pf.full_name,
    pf.phone_number,
    pr.workshop_name,
    pr.address,
    pr.latitude,
    pr.longitude,
    pr.support_scope,
    pr.has_vehicle,
    pr.vehicle_type,
    pr.vehicle_specs,
    pr.is_online,
    pr.created_at,
    COALESCE(rt.avg_rating, 0::double precision) AS avg_rating,
    COALESCE(rt.rating_count, 0::bigint) AS rating_count,
    COALESCE(ar.services, '{}'::text[]) AS services,
    pf.avatar_id,
    pf.avatar_url
   FROM providers pr
     JOIN profiles pf ON pf.id = pr.id
     LEFT JOIN ( SELECT ratings.provider_id,
            avg(ratings.rating)::double precision AS avg_rating,
            count(*)::bigint AS rating_count
           FROM ratings
          WHERE ratings.counted_in_average
          GROUP BY ratings.provider_id) rt ON rt.provider_id = pr.id
     LEFT JOIN ( SELECT provider_specializations.provider_id,
            array_agg(provider_specializations.service_type_id ORDER BY provider_specializations.service_type_id) AS services
           FROM provider_specializations
          GROUP BY provider_specializations.provider_id) ar ON ar.provider_id = pr.id;

-- 5) الآراء العامة للمزود: الاسم الثنائي + avatar فقط مع اسم الخدمة.
--    قائمة الآراء تعرض كل التقييمات (حتى غير المحسوب) — الاحتساب للمتوسط فقط.
create or replace function public.get_provider_reviews(
  p_provider_id uuid,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  rating integer,
  comment text,
  created_at timestamp with time zone,
  service_type_id text,
  service_name_ar text,
  service_name_en text,
  reviewer_name text,
  reviewer_avatar_id text,
  reviewer_avatar_url text,
  total_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer;
  v_offset integer;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  return query
  select
    r.rating,
    r.comment,
    r.created_at,
    o.service_type_id,
    st.name_ar,
    st.name_en,
    -- الاسم الثنائي فقط: أول مقطعين بعد تطبيع المسافات، بلا أي جزء ثالث.
    nullif(
      array_to_string(
        (string_to_array(trim(regexp_replace(pf.full_name, '\s+', ' ', 'g')), ' '))[1:2],
        ' '
      ),
      ''
    ) as reviewer_name,
    pf.avatar_id,
    pf.avatar_url,
    count(*) over () as total_count
  from public.ratings r
  join public.orders o on o.id = r.order_id
  join public.profiles pf on pf.id = r.user_id
  left join public.service_types st on st.id = o.service_type_id
  where r.provider_id = p_provider_id
  order by r.created_at desc, r.id desc
  limit v_limit offset v_offset;
end;
$$;

-- 6) عدد الطلبات المكتملة للمزود (RLS على orders تمنع عدّ طلبات غيره).
create or replace function public.get_provider_completed_orders(p_provider_id uuid)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  return (
    select count(*)
    from public.orders o
    where o.provider_id = p_provider_id
      and o.status = 'completed'
  );
end;
$$;

-- 7) صلاحيات: للحسابات المسجلة فقط (لا anon)، ولا معاينة إدارة.
revoke all on function public.get_provider_reviews(uuid, integer, integer) from public, anon;
revoke all on function public.get_provider_completed_orders(uuid) from public, anon;
grant execute on function public.get_provider_reviews(uuid, integer, integer) to authenticated, service_role;
grant execute on function public.get_provider_completed_orders(uuid) to authenticated, service_role;

-- 8) لوحة الإدارة: عدد العملاء المختلفين + عدد الصفوف المحسوبة بجانب المتوسط.
create or replace function public.admin_get_user(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
        'id', v.id,
        'make', b.name_ar,
        'model', m.name_ar,
        'year', v.model_year,
        'plate_number', nullif(concat_ws(' ', v.plate_letters, v.plate_digits), ''),
        'color', c.name_ar,
        'trim', t.name_ar,
        'brand_id', b.id,
        'created_at', v.created_at
      ) order by v.created_at), '[]'::jsonb)
      from public.vehicles v
      join public.vehicle_trims t on t.id = v.trim_id
      join public.vehicle_generations g on g.id = t.generation_id
      join public.vehicle_models m on m.id = g.model_id
      join public.vehicle_brands b on b.id = m.brand_id
      left join public.vehicle_colors c on c.id = v.color_id
      where v.user_id = p_user_id
    ),
    'provider', (
      select
        case when count(*) = 0 then null else jsonb_build_object(
          'workshop_name',    max(pw.workshop_name),
          'address',          max(pw.address),
          'latitude',         max(pw.latitude),
          'longitude',        max(pw.longitude),
          'support_scope',    max(pw.support_scope::text),
          'has_vehicle',      coalesce(bool_or(pw.has_vehicle), false),
          'vehicle_specs',    max(pw.vehicle_specs),
          'is_online',        coalesce(bool_or(pw.is_online), false),
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
        'avg', round((avg(rating) filter (where counted_in_average))::numeric, 2),
        'count', count(*) filter (where counted_in_average),
        'total', count(*),
        'distinct_raters', count(distinct user_id)
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
$function$;
