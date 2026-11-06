-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20261017024249 | name: admin_rpc_require_admin_hotfix
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- =============================================================================
-- Hotfix: admin_notification_activity and admin_recent_activity were SECURITY DEFINER,
-- executable by any authenticated user, and had NO admin check (data leak: other users'
-- names/phones/emails and notification history). Rebuild them as plpgsql that call
-- assert_admin() first. Bodies are otherwise unchanged.

create or replace function public.admin_notification_activity(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
begin
  perform public.assert_admin();

  return (
    select jsonb_build_object(
      'summary', (
        select coalesce(jsonb_object_agg(s.type, s.cnt), '{}'::jsonb)
        from (
          select type, count(*) as cnt
          from public.notifications
          where user_id = p_user_id
          group by type
        ) s
      ),
      'recent', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id',         n.id,
          'type',       n.type,
          'order_id',   n.order_id,
          'is_read',    n.is_read,
          'created_at', n.created_at
        ) order by n.created_at desc), '[]'::jsonb)
        from (
          select n.*, row_number() over (order by n.created_at desc) as rn
          from public.notifications n
          where n.user_id = p_user_id
        ) n
        where n.rn <= 30
      )
    )
  );
end;
$function$;

create or replace function public.admin_recent_activity()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
begin
  perform public.assert_admin();

  return (
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
    )
  );
end;
$function$;

revoke all on function public.admin_notification_activity(uuid) from public, anon;
revoke all on function public.admin_recent_activity() from public, anon;
grant execute on function public.admin_notification_activity(uuid) to authenticated;
grant execute on function public.admin_recent_activity() to authenticated;
