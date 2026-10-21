-- =============================================================================
-- Fix: pg has no max(boolean) - the provider aggregate in admin_get_user used
-- max() over boolean columns (has_vehicle / is_online). Replaced with bool_or
-- (correct per-row OR semantics; block only runs when at least one row exists).
-- =============================================================================

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