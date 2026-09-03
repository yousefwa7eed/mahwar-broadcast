-- Migration: Add cleanup_user_data function for account deletion
-- Date: 2026-08-19

-- ============================================================================
-- 1. Create cleanup_user_data function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cleanup_user_data(p_user_id uuid DEFAULT auth.uid())
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    DELETE FROM public.notifications WHERE user_id = p_user_id;
    DELETE FROM public.orders WHERE car_owner_id = p_user_id OR provider_id = p_user_id;
    DELETE FROM public.provider_specializations WHERE provider_id = p_user_id;
    DELETE FROM public.provider_car_details WHERE provider_id = p_user_id;
    DELETE FROM public.providers WHERE id = p_user_id;
    DELETE FROM public.car_details WHERE user_id = p_user_id;
    DELETE FROM public.profiles WHERE id = p_user_id;
END;
$$;

-- ============================================================================
-- 2. Lock down permissions - only service_role can call this function
-- ============================================================================
REVOKE ALL ON FUNCTION public.cleanup_user_data(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cleanup_user_data(uuid) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_user_data(uuid) TO service_role;
