-- Migration: Add get_email_by_phone RPC function for phone-based login
-- Date: 2026-08-20

-- ============================================================================
-- 1. Create get_email_by_phone function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_email_by_phone(p_phone text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_email text;
BEGIN
    SELECT email INTO v_email
    FROM public.profiles
    WHERE phone_number = p_phone
    LIMIT 1;

    RETURN v_email;
END;
$$;

-- ============================================================================
-- 2. Grant execute permission to anon and authenticated roles
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.get_email_by_phone(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_email_by_phone(text) TO authenticated;
