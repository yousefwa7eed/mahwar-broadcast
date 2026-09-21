-- =============================================================================
-- Auto-toggle providers.is_online at schedule boundaries (issue #16).
--
-- Confirmed design (Design 2):
--   * is_online is the single visibility gate in get_nearest_providers (the
--     schedule AND is removed by 20260916143000_drop_schedule_gate_from_nearest_providers.sql).
--   * provider_schedules only drives WHEN is_online flips:
--       - at the open boundary  -> is_online = true  (only if currently false)
--       - at the close boundary -> is_online = false (only if currently true)
--   * No other minute is ever written, so:
--       - a manual mid-shift OFF (break) is respected until the next boundary;
--       - a manual ON outside hours is respected until the next real boundary;
--       - providers with NO schedule rows are never touched (manual toggle only).
--   * Wall clock is Africa/Cairo (no DST), same convention as is_provider_available_now.
--   * Runs via pg_cron every minute: same pattern as expire-overdue-orders
--     (20260913110000_in_db_auto_cancel.sql).
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
  -- Open boundary reached (within the current minute) -> turn ON.
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
     );

  -- Close boundary reached (within the current minute) -> turn OFF.
  -- If the same provider is hitting an open boundary this exact minute
  -- (degenerate back-to-back split shift), the open boundary wins.
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
     );
end;
$$;

comment on function public.flip_provider_availability_at_boundaries() is
  'Cron-only. At each scheduled open/close boundary in Africa/Cairo, flips providers.is_online respectively, but only at the exact boundary minute (never mid-window, never outside a boundary).';

-- Cron-only helper: not meant to be called by clients.
revoke execute on function public.flip_provider_availability_at_boundaries() from public, authenticated;

-- Wire the every-minute cron (idempotent repoint, same pattern as
-- expire-overdue-orders-every-minute).
do $$
begin
  perform cron.unschedule('autotoggle-provider-availability-every-minute');
exception when others then
  null;
end;
$$;
select cron.schedule(
  'autotoggle-provider-availability-every-minute',
  '* * * * *',
  'select public.flip_provider_availability_at_boundaries();'
);