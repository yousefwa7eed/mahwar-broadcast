-- =============================================================================
-- Query-time availability (= manual is_online AND within working hours).
--
-- Rolls out the provider_schedules table (20260916130000) into the live
-- "find a provider" path:
--
--   * is_provider_available_now(provider_id) computes whether the provider is
--     open on the current weekday at the current wall-clock time in Egypt
--     (Africa/Cairo, no DST). A provider with NO schedule rows counts as
--     always available (no constraint) — existing/test providers keep current
--     behaviour until they explicitly save a schedule.
--   * get_nearest_providers(...) now filters p.is_online = true AND
--     is_provider_available_now(...). The manual on/off toggle remains purely
--     manual; the schedule is an additional AND condition.
-- =============================================================================

drop function if exists public.is_provider_available_now(uuid);
create or replace function public.is_provider_available_now(p_provider_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select case
    when count(*) = 0 then true
    else bool_and(
      s.is_closed = false
      and s.open_time is not null
      and s.close_time is not null
      and (now() at time zone 'Africa/Cairo')::time between s.open_time and s.close_time
    )
  end
  from public.provider_schedules s
  where s.provider_id = p_provider_id
    and s.day_of_week = extract(dow from now() at time zone 'Africa/Cairo')::int;
$$;

comment on function public.is_provider_available_now(uuid) is
  'True when the provider is open right now in Africa/Cairo, or has no schedule rows (no constraint). Used by get_nearest_providers.';

-- Rewrite get_nearest_providers adding the working-hours filter.
drop function if exists public.get_nearest_providers(double precision, double precision, text, double precision);
create or replace function public.get_nearest_providers(
  user_lat double precision,
  user_lng double precision,
  service_filter text default null,
  max_distance_meters double precision default 50000
)
returns table(
  provider_id uuid,
  full_name text,
  phone_number text,
  workshop_name text,
  address text,
  latitude double precision,
  longitude double precision,
  distance_meters double precision,
  support_scope public.support_scope,
  has_vehicle boolean,
  is_online boolean,
  avg_rating double precision,
  rating_count bigint,
  services text[]
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select
    p.provider_id,
    p.full_name,
    p.phone_number,
    p.workshop_name,
    p.address,
    p.latitude,
    p.longitude,
    public.earth_distance(
      public.ll_to_earth(user_lat, user_lng),
      public.ll_to_earth(p.latitude, p.longitude)
    ) as distance_meters,
    p.support_scope,
    p.has_vehicle,
    p.is_online,
    p.avg_rating,
    p.rating_count,
    p.services
  from public.public_provider_profiles p
  where p.is_online = true
    and public.is_provider_available_now(p.provider_id)
    and (service_filter is null or p.services @> array[service_filter])
    and public.earth_distance(
      public.ll_to_earth(user_lat, user_lng),
      public.ll_to_earth(p.latitude, p.longitude)
    ) <= max_distance_meters
  order by distance_meters asc;
end;
$$;