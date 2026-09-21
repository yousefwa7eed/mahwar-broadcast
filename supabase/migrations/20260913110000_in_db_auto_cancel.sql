-- =============================================================================
-- Make auto-cancel reliable by doing it IN THE DATABASE.
--
-- Why: the previous pipeline (pg_cron → net.http_post → edge function with an
-- x-order-event-secret check) never delivered in production — pending orders
-- stayed pending forever (the secret/env mismatch makes the function return 403,
-- so the every-minute cron silently did nothing).
--
--  1) Drops the legacy `order_respond_deadline` trigger (set_respond_deadline)
--     that overwrote the customer's 5-minute auto-cancel deadline with a fixed
--     now()+3 min whenever a provider was assigned — that broke the customer's
--     choice and the countdown.
--  2) Adds `expire_overdue_orders()` — a SECURITY DEFINER job that cancels only
--     orders with auto_cancel = true whose deadline passed (with the legacy
--     fallback for NULL deadlines: created > 5 minutes ago), and notifies owners.
--  3) Repoints the every-minute cron job from the HTTP edge-function call to a
--     direct SQL call.
--
-- The existing AFTER UPDATE trigger `order_terminal_cleanup` (storage cleanup)
-- and the `notifications` → push trigger still fire as before.
-- =============================================================================

-- 1) Remove the legacy 3-minute assignment deadline.
drop trigger if exists order_respond_deadline on public.orders;
drop function if exists public.set_respond_deadline();

-- 2) In-database auto-cancel job.
create or replace function public.expire_overdue_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cancelled jsonb;
  v_count integer := 0;
begin
  with updated as (
    update public.orders
    set status = 'cancelled',
        respond_deadline = null,
        updated_at = now()
    where status = 'pending'
      and auto_cancel
      and (
        (respond_deadline is not null and respond_deadline < now())
        or (respond_deadline is null and created_at < now() - interval '5 minutes')
      )
    returning id, car_owner_id
  )
  select jsonb_agg(to_jsonb(updated)) into v_cancelled from updated;

  if v_cancelled is not null then
    insert into public.notifications (user_id, order_id, type, metadata)
    select (row->>'car_owner_id')::uuid,
           (row->>'id')::uuid,
           'order_cancelled',
           '{"by":"timeout"}'::jsonb
    from jsonb_array_elements(v_cancelled) as row
    where exists (
      select 1 from public.profiles p where p.id = (row->>'car_owner_id')::uuid
    );
    v_count := jsonb_array_length(v_cancelled);
  end if;

  return v_count;
end;
$$;

-- Cron-only function: not meant to be called by clients.
revoke execute on function public.expire_overdue_orders() from public, authenticated;

-- 3) Repoint the every-minute cron from the failing HTTP edge-function call to a
--    direct SQL call (fresh installs: the old job name may not exist — ignore).
do $$
begin
  perform cron.unschedule('expire-pending-orders');
exception when others then
  null;
end;
$$;
select cron.schedule('expire-overdue-orders-every-minute', '* * * * *',
                     'select public.expire_overdue_orders();');