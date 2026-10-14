-- =============================================================================
-- Provider availability: a manual override that outlives the app session.
--
-- The home-screen toggle used to remember the manual decision only in memory
-- (_manuallyOnline / _manuallyOffline). Any screen re-entry, app restart or
-- process death lost it, and the every-2s poll re-converged the toggle onto
-- the schedule — so a provider could not stay available outside working hours
-- (nor stay hidden inside them) reliably.
--
-- We persist the manual decision on the provider row:
--   availability_override = 'auto' -> schedule governs (default; legacy rows)
--                         = 'on'   -> provider forced available until changed
--                         = 'off'  -> provider forced unavailable until changed
--
-- The schedule still wins at its boundaries: the every-minute flipper now also
-- resets availability_override to 'auto' whenever it flips is_online, so a
-- manual decision survives until the provider changes it OR the next
-- scheduled open/close boundary, whichever comes first.
-- =============================================================================

alter table public.providers
  add column if not exists availability_override text not null default 'auto';

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conname = 'providers_availability_override_check'
  ) then
    alter table public.providers
      add constraint providers_availability_override_check
      check (availability_override in ('auto', 'on', 'off'));
  end if;
end $$;

comment on column public.providers.availability_override is
  'Manual availability override set from the provider home toggle. auto = schedule governs; on/off = provider-forced until they change it or the next schedule boundary (the every-minute cron resets it to auto when it flips is_online).';

-- -----------------------------------------------------------------------------
-- Snapshot RPC: also expose the current override so the home-screen poll can
-- tell "schedule governs" apart from "provider made an explicit choice".
-- Return type changes, so drop + recreate (create or replace cannot).
-- -----------------------------------------------------------------------------
drop function if exists public.provider_availability_snapshot(uuid);

create or replace function public.provider_availability_snapshot(
  p_provider_id uuid
)
returns table (has_schedule boolean, in_hours boolean, availability_override text)
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
    ))::boolean as in_hours,
    coalesce(
      (select p.availability_override
         from public.providers p
        where p.id = p_provider_id),
      'auto'
    )::text as availability_override;
$$;

comment on function public.provider_availability_snapshot(uuid) is
  'Returns whether the provider has any schedule rows, whether they are inside working hours right now (open <= now < close, Africa/Cairo), and their manual availability_override (auto/on/off). Used by the provider home screen poll to keep the toggle in sync with the schedule while honouring an explicit manual override.';

-- -----------------------------------------------------------------------------
-- Boundary flipper: reset the manual override to 'auto' on every flip, so the
-- schedule reasserts itself at the next open/close boundary.
-- -----------------------------------------------------------------------------
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
       set is_online = true,
           availability_override = 'auto'
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
       set is_online = false,
           availability_override = 'auto'
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
  'Cron-only. At each scheduled open/close boundary in Africa/Cairo, flips providers.is_online at the exact boundary minute (never mid-window, never outside a boundary), resets availability_override to auto, and records a shift_started/shift_ended notification (push follows via the notifications trigger).';

-- Cron-only helper: not meant to be called by clients.
revoke execute on function public.flip_provider_availability_at_boundaries() from public, authenticated;
