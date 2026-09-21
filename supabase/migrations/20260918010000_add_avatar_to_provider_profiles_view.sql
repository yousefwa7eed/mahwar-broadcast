-- Migration: Add avatar_id and avatar_url to public_provider_profiles view and get_provider_details RPC

-- 1) Update the view to include avatar_id and avatar_url
CREATE OR REPLACE VIEW public.public_provider_profiles AS
SELECT
  pr.id AS provider_id,
  pf.full_name,
  pf.phone_number,
  pr.workshop_name,
  pr.address,
  pr.latitude,
  pr.longitude,
  pr.support_scope,
  pr.has_vehicle,
  pr.vehicle_type,
  pr.vehicle_specs,
  pr.is_online,
  pr.created_at,
  COALESCE(rt.avg_rating, 0)::DOUBLE PRECISION AS avg_rating,
  COALESCE(rt.rating_count, 0)::BIGINT AS rating_count,
  COALESCE(ar.services, '{}') AS services,
  pf.avatar_id,
  pf.avatar_url
FROM public.providers pr
JOIN public.profiles pf ON pf.id = pr.id
LEFT JOIN (
  SELECT provider_id, AVG(rating)::DOUBLE PRECISION AS avg_rating, COUNT(*)::BIGINT AS rating_count
  FROM public.ratings
  GROUP BY provider_id
) rt ON rt.provider_id = pr.id
LEFT JOIN (
  SELECT provider_id, ARRAY_AGG(service_id) AS services
  FROM public.provider_services
  GROUP BY provider_id
) ar ON ar.provider_id = pr.id;

-- 2) Update get_provider_details RPC to return avatar_id and avatar_url
DROP FUNCTION IF EXISTS public.get_provider_details(uuid);
CREATE OR REPLACE FUNCTION public.get_provider_details(p_provider_id uuid)
RETURNS TABLE(
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
  avatar_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET SEARCH_PATH = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
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
    p.avatar_url
  FROM public.public_provider_profiles p
  WHERE p.provider_id = p_provider_id
  LIMIT 1;
END;
$$;