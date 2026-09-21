-- =============================================================================
-- Shift-boundary push notifications for providers (issue: alert at shift start/end).
--
-- The every-minute cron function already flips providers.is_online exactly at
-- the schedule's open/close boundary minutes. Here we enrich that function so
-- that every flip it performs ALSO records an in-app notification:
--   * turned ON  at the open boundary  -> type 'shift_started'
--   * turned OFF at the close boundary -> type 'shift_ended'
--
-- Notification rows are the single source of truth (same pattern as
-- expire-pending-orders): the existing `on_notification_created` trigger fires
-- notify_push() via pg_net, which calls send-push-notification (FCM) and the
-- app's bell/list sync automatically. No extra cron, no extra edge function.
--
-- The flip predicates guarantee one notification per boundary per provider
-- (they only match within the exact boundary minute, and the UPDATE's WHERE
-- already limits to rows whose value actually changes), so there is no
-- duplicate-spam risk across minutes.
-- =============================================================================

create or replace function public.flip_provider_availability_at_boundaries()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day  int  := extract(dow from now() at time zone 'Africa/Cairo')::int;
  v_time time := (now() at time zone 'Africa/Cairo')::time;
begin
  -- Open boundary reached (within the current minute) -> turn ON + notify.
  with flipped as (
    update public.providers p
       set is_online = true
     where p.is_online = false
       and p.id in (
         select s.provider_id
           from public.provider_schedules s
          where s.day_of_week = v_day
            and s.is_closed   = false
            and s.open_time   is not null
            and s.close_time  is not null
            and v_time >= s.open_time
            and v_time <  s.open_time + interval '1 minute'
       )
     returning p.id
  )
  insert into public.notifications (user_id, type, metadata)
  select id, 'shift_started', '{"deep_link":"provider_home"}'::jsonb
    from flipped;

  -- Close boundary reached (within the current minute) -> turn OFF + notify.
  -- If the same provider is hitting an open boundary this exact minute
  -- (degenerate back-to-back split shift), the open boundary wins.
  with flipped as (
    update public.providers p
       set is_online = false
     where p.is_online = true
       and p.id in (
         select s.provider_id
           from public.provider_schedules s
          where s.day_of_week = v_day
            and s.is_closed   = false
            and s.open_time   is not null
            and s.close_time  is not null
            and v_time >= s.close_time
            and v_time <  s.close_time + interval '1 minute'
            and not exists (
              select 1
                from public.provider_schedules s2
               where s2.provider_id = s.provider_id
                 and s2.day_of_week = v_day
                 and s2.is_closed   = false
                 and s2.open_time   is not null
                 and s2.close_time  is not null
                 and v_time >= s2.open_time
                 and v_time <  s2.open_time + interval '1 minute'
            )
       )
     returning p.id
  )
  insert into public.notifications (user_id, type, metadata)
  select id, 'shift_ended', '{"deep_link":"provider_home"}'::jsonb
    from flipped;
end;
$$;

comment on function public.flip_provider_availability_at_boundaries() is
  'Cron-only. At each scheduled open/close boundary in Africa/Cairo, flips providers.is_online at the exact boundary minute (never mid-window, never outside a boundary) and records a shift_started/shift_ended notification (push follows via the notifications trigger).';

-- Cron-only helper: not meant to be called by clients.
revoke execute on function public.flip_provider_availability_at_boundaries() from public, authenticated;