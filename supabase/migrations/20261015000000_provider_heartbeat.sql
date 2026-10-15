-- =============================================================================
-- Phase 2B-1: provider heartbeat + location-freshness exposure.
--
-- Providers now keep their stored location fresh by sending a lightweight
-- "heartbeat" while they are ONLINE and the app is in the foreground:
--
--   provider_heartbeat(p_lat, p_lng, p_accuracy)
--
-- The RPC derives the provider from auth.uid() (no provider-id parameter, so a
-- provider can only ever touch their OWN row), always stamps the freshness
-- timestamp, and refuses to move the stored coordinates on a poor GPS fix
-- (accuracy > 200 m) — a bad fix must never relocate a provider on the map.
--
-- Two read RPCs then expose the new freshness timestamp as a NULLABLE column at
-- the END of their result list so clients can show/act on it later:
--   * get_nearest_providers(...) -> + location_updated_at
--   * get_provider_details(...)  -> + location_updated_at
--
-- Both are return-type changes (DROP + CREATE). We keep SECURITY DEFINER,
-- search_path = '', every pre-existing column in the same order, and the
-- existing delegation to is_provider_eligible_for_order UNCHANGED. No freshness
-- FILTER is added yet — this phase only exposes the metadata.
--
-- Nothing here is applied automatically: review, then apply.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1) provider_heartbeat: the single write path for a provider's live location.
--    * SECURITY DEFINER + search_path = '' (schema-qualified everywhere).
--    * Identity comes ONLY from auth.uid() — no provider-id parameter.
--    * Raises if the caller has no row in public.providers.
--    * Validates lat/lng/accuracy ranges.
--    * ALWAYS stamps location_updated_at = now() and location_accuracy.
--    * Updates latitude/longitude ONLY when the fix is usable
--      (p_accuracy IS NULL OR p_accuracy <= 200).
-- -----------------------------------------------------------------------------
create or replace function public.provider_heartbeat(
  p_lat double precision,
  p_lng double precision,
  p_accuracy double precision default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider_id uuid := auth.uid();
begin
  if v_provider_id is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not exists (select 1 from public.providers pr where pr.id = v_provider_id) then
    raise exception 'PROVIDER_NOT_FOUND';
  end if;

  if p_lat is null or p_lat < -90 or p_lat > 90 then
    raise exception 'INVALID_LATITUDE';
  end if;

  if p_lng is null or p_lng < -180 or p_lng > 180 then
    raise exception 'INVALID_LONGITUDE';
  end if;

  if p_accuracy is not null and p_accuracy < 0 then
    raise exception 'INVALID_ACCURACY';
  end if;

  update public.providers
     set location_updated_at = now(),
         location_accuracy   = p_accuracy,
         latitude            = case
                                 when p_accuracy is null or p_accuracy <= 200 then p_lat
                                 else latitude
                               end,
         longitude           = case
                                 when p_accuracy is null or p_accuracy <= 200 then p_lng
                                 else longitude
                               end
   where id = v_provider_id;
end;
$$;

comment on function public.provider_heartbeat(double precision, double precision, double precision) is
  'Provider-only location heartbeat. Resolves the provider from auth.uid(), always stamps location_updated_at/location_accuracy, and moves latitude/longitude only when p_accuracy is NULL or <= 200 m.';

revoke all on function public.provider_heartbeat(double precision, double precision, double precision) from public, anon;
grant execute on function public.provider_heartbeat(double precision, double precision, double precision) to authenticated;


-- -----------------------------------------------------------------------------
-- 2) get_nearest_providers: expose location_updated_at as the LAST column.
--    Return type changes -> DROP + CREATE. Body is otherwise identical to the
--    live definition (same columns, same delegation, no freshness filter).
-- -----------------------------------------------------------------------------
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
  services text[],
  location_updated_at timestamptz
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
    p.services,
    (select pr.location_updated_at
       from public.providers pr
      where pr.id = p.provider_id) as location_updated_at
  from public.public_provider_profiles p
  where public.is_provider_eligible_for_order(
          p.provider_id, service_filter, user_lat, user_lng, max_distance_meters
        )
  order by distance_meters asc;
end;
$$;

comment on function public.get_nearest_providers(double precision, double precision, text, double precision) is
  'Nearby online providers for an owner, ordered by great-circle distance. Now also returns location_updated_at (NULL when the provider never sent a heartbeat); no freshness filtering is applied.';

revoke all on function public.get_nearest_providers(double precision, double precision, text, double precision) from public, anon;
grant execute on function public.get_nearest_providers(double precision, double precision, text, double precision) to authenticated;


-- -----------------------------------------------------------------------------
-- 3) get_provider_details: expose location_updated_at as the LAST column.
--    Same DROP + CREATE treatment; every existing column is preserved in order.
-- -----------------------------------------------------------------------------
drop function if exists public.get_provider_details(uuid);

create or replace function public.get_provider_details(p_provider_id uuid)
returns table(
  provider_id uuid,
  full_name text,
  phone_number text,
  workshop_name text,
  address text,
  latitude double precision,
  longitude double precision,
  support_scope public.support_scope,
  has_vehicle boolean,
  vehicle_type text,
  vehicle_specs text,
  is_online boolean,
  avg_rating double precision,
  rating_count bigint,
  services text[],
  avatar_id text,
  avatar_url text,
  location_updated_at timestamptz
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
    p.support_scope,
    p.has_vehicle,
    p.vehicle_type,
    p.vehicle_specs,
    p.is_online,
    p.avg_rating,
    p.rating_count,
    p.services,
    p.avatar_id,
    p.avatar_url,
    (select pr.location_updated_at
       from public.providers pr
      where pr.id = p.provider_id) as location_updated_at
  from public.public_provider_profiles p
  where p.provider_id = p_provider_id
  limit 1;
end;
$$;

comment on function public.get_provider_details(uuid) is
  'Full public profile for one provider. Now also returns location_updated_at (NULL when the provider never sent a heartbeat).';

revoke all on function public.get_provider_details(uuid) from public, anon;
grant execute on function public.get_provider_details(uuid) to authenticated;


-- =============================================================================
-- VERIFICATION (run manually; read-only except the rolled-back test call).
-- =============================================================================
--
-- (a) Signatures / return types.
--
-- select p.proname,
--        pg_get_function_identity_arguments(p.oid) as args,
--        pg_get_function_result(p.oid)          as result
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and p.proname in ('provider_heartbeat','get_nearest_providers','get_provider_details')
--  order by p.proname;
--
-- (b) Grants: anon must have NO execute; authenticated must have execute.
--
-- select p.proname,
--        coalesce(array_to_string(p.proacl, ', '), '(default)') as acl
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and p.proname in ('provider_heartbeat','get_nearest_providers','get_provider_details')
--  order by p.proname;
-- -- expect: postgres=X/..., authenticated=X/..., service_role=X/...
-- --         (no "=X/" entry for PUBLIC, no anon=)
--
-- (c) Rolled-back functional test. Replace the two uuid literals with a real
--     provider id and a real authenticated user id, and run inside psql as that
--     user (auth.uid() has no meaning in the SQL editor). The whole block rolls
--     back, so nothing is persisted.
--
-- begin;
--   -- create a throwaway provider row owned by :provider_id, then heartbeat it.
--   -- (adjust columns if your providers table has extra NOT NULL columns)
--   select public.provider_heartbeat(30.0444, 31.2357, 15.0);   -- valid, moves coords
--   select public.provider_heartbeat(30.0500, 31.2400, 350.0);  -- poor fix: timestamp only
--   select public.provider_heartbeat(200.0,  31.0,   10.0);     -- raises INVALID_LATITUDE
-- rollback;
--
-- (d) After a real heartbeat, the new column is visible:
--
-- select provider_id, location_updated_at
--   from public.get_nearest_providers(30.0444, 31.2357, null, 50000)
--  limit 5;
--
-- select provider_id, location_updated_at
--   from public.get_provider_details('00000000-0000-0000-0000-000000000000');
