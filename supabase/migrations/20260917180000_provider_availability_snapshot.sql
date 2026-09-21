-- =============================================================================
-- providers home screen schedule poll
--
-- The cron flipper (autotoggle-provider-availability-every-minute) only turns
-- is_online on/off during the exact boundary minute. If a provider edits the
-- schedule so that the open boundary has already passed (or a day becomes
-- closed / out-of-hours later), the stored is_online never converges and the
-- home toggle stays stale.
--
-- This function gives the home screen everything it needs in ONE call to fix
-- that: whether the provider has any schedule rows at all (no rows = fully
-- manual control, never auto-correct) and whether the provider is inside
-- working hours *right now* — using the SAME rule as the cron flipper
-- (open <= now < close, Africa/Cairo) so the poll converges onto what the
-- flipper would do, not onto the slightly different "nearest providers" view.
-- =============================================================================

drop function if exists public.provider_availability_snapshot(uuid);

create or replace function public.provider_availability_snapshot(
  p_provider_id uuid
)
returns table (has_schedule boolean, in_hours boolean)
language sql
security definer
set search_path = ''
stable
as $$
  select
    (exists (
      select 1 from public.provider_schedules s
        where s.provider_id = p_provider_id
    ))::boolean as has_schedule,
    (exists (
      select 1 from public.provider_schedules s
        where s.provider_id = p_provider_id
          and s.day_of_week = extract(dow from now() at time zone 'Africa/Cairo')::int
          and s.is_closed = false
          and s.open_time is not null
          and s.close_time is not null
          and (now() at time zone 'Africa/Cairo')::time >= s.open_time
          and (now() at time zone 'Africa/Cairo')::time < s.close_time
    ))::boolean as in_hours;
$$;

comment on function public.provider_availability_snapshot(uuid) is
  'Returns whether the provider has any schedule rows and whether they are inside working hours right now (open <= now < close, Africa/Cairo). Used by the provider home screen poll to keep the toggle in sync with the schedule.';