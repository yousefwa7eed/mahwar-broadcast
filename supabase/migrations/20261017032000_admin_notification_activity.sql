-- =============================================================================
-- Admin helper: full notification activity trail for one user.
-- Yousef asked why "الوكيل" shows only 1 order: the ORDERS table has only the
-- assigned ones; request/broadcast/shift activity lives in notifications.
-- This RPC exposes it to the dashboard without touching admin_get_user.
-- =============================================================================

create or replace function public.admin_notification_activity(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
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
  );
$$;

revoke all on function public.admin_notification_activity(uuid) from public;
revoke all on function public.admin_notification_activity(uuid) from anon;
grant execute on function public.admin_notification_activity(uuid) to authenticated, service_role;