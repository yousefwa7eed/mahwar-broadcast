-- Migration: Add avatar_id and avatar_url to get_public_profile RPC

DROP FUNCTION IF EXISTS public.get_public_profile(uuid);
CREATE OR REPLACE FUNCTION public.get_public_profile(p_user_id uuid)
RETURNS TABLE(
  full_name text,
  phone_number text,
  role public.user_role,
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
    pf.full_name,
    pf.phone_number,
    pf.role,
    pf.avatar_id,
    pf.avatar_url
  FROM public.profiles pf
  WHERE pf.id = p_user_id;
END;
$$;