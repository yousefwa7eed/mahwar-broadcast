-- =============================================================================
-- Provider working hours.
--
-- One row per provider per weekday (0 = Sunday .. 6 = Saturday, matching
-- PostgreSQL extract(dow ...)). A provider with NO rows in this table is
-- "always available" (no automatic schedule constraint).
--
-- When is_closed is false the provider must supply an open/close pair where
-- open_time < close_time (no overnight shifts yet; relax later if needed).
-- When is_closed is true the times are ignored (kept null on the client).
-- =============================================================================

create table if not exists public.provider_schedules (
  provider_id uuid not null references public.providers(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  open_time time without time zone,
  close_time time without time zone,
  is_closed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (provider_id, day_of_week),
  constraint provider_schedules_open_range check (
    is_closed = true
      or (open_time is not null and close_time is not null and open_time < close_time)
  )
);

comment on table public.provider_schedules is
  'Working hours per provider. Empty table means the provider has no schedule constraint.';
comment on column public.provider_schedules.day_of_week is
  '0 = Sunday, 1 = Monday ... 6 = Saturday (PostgreSQL extract(dow)).';
comment on column public.provider_schedules.is_closed is
  'true = provider is closed this day regardless of the time columns.';

alter table public.provider_schedules enable row level security;
alter table public.provider_schedules force row level security;

drop policy if exists "Provider manages own schedule" on public.provider_schedules;
create policy "Provider manages own schedule"
  on public.provider_schedules
  as permissive
  for all
  to authenticated
  using (auth.uid() = provider_id)
  with check (auth.uid() = provider_id);