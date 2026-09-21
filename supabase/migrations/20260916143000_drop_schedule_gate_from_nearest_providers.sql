-- =============================================================================
-- Design 2: is_online is the SINGLE visibility gate in get_nearest_providers.
--
-- The working-hours schedule no longer hides an online provider outside their
-- rows: visibility = is_online = true AND service filter AND distance.
-- The schedule's only role is driving the every-minute boundary auto-flip
-- (20260916140000_auto_toggle_availability_boundaries.sql).
--
-- Signature and returns are unchanged -> zero client code changes.
-- is_provider_available_now(uuid) is kept (now unused by this query) for a
-- future "متاح حالياً؟" label on provider details.
-- =============================================================================

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
    and (service_filter is null or p.services @> array[service_filter])
    and public.earth_distance(
      public.ll_to_earth(user_lat, user_lng),
      public.ll_to_earth(p.latitude, p.longitude)
    ) <= max_distance_meters
  order by distance_meters asc;
end;
$$;