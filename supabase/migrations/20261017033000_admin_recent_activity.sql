-- =============================================================================
-- Overview extras: latest 5 registered users + latest 5 orders (with names).
-- Name fallback: auth.users email when the profile row is missing (e.g. the
-- converted admin account). Fills the dashboard home page with real activity.
-- =============================================================================

create or replace function public.admin_recent_activity()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'latest_users', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id',         u.id,
        'full_name',  u.full_name,
        'role',       u.role::text,
        'phone',      u.phone_number,
        'created_at', u.created_at
      ) order by u.created_at desc), '[]'::jsonb)
      from (
        select pr.*, row_number() over (order by pr.created_at desc) as rn
        from public.profiles pr
      ) u
      where u.rn <= 5
    ),
    'latest_orders', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id',            o.id,
        'status',        o.status::text,
        'service',       st.name_ar,
        'offered_price', o.offered_price,
        'owner_name',    coalesce(owner_p.full_name, owner_au.email),
        'provider_name', coalesce(provider_p.full_name, provider_au.email),
        'owner_missing_profile', owner_p.id is null,
        'created_at',    o.created_at
      ) order by o.created_at desc), '[]'::jsonb)
      from (
        select o.*, row_number() over (order by o.created_at desc) as rn
        from public.orders o
      ) o
      left join public.service_types st on st.id = o.service_type_id
      left join public.profiles owner_p    on owner_p.id = o.car_owner_id
      left join auth.users    owner_au     on owner_au.id = o.car_owner_id
      left join public.profiles provider_p on provider_p.id = o.provider_id
      left join auth.users    provider_au  on provider_au.id = o.provider_id
      where o.rn <= 5
    )
  );
$$;

revoke all on function public.admin_recent_activity() from public;
revoke all on function public.admin_recent_activity() from anon;
grant execute on function public.admin_recent_activity() to authenticated, service_role;