-- Migration: Enforce ownership on update_auth_email.
-- Date: 2026-09-18
--
-- The live function was SECURITY DEFINER and updated auth.users by p_user_id
-- with no ownership check, allowing any authenticated user to change another
-- user's email (account-takeover primitive). The earlier migration
-- 20260820000001_add_update_auth_email.sql added a `<>` guard but was never
-- applied to the live database.
--
-- This uses IS DISTINCT FROM so a NULL auth.uid() (anon / stray caller) is also
-- rejected, not silently allowed by NULL comparison semantics.

CREATE OR REPLACE FUNCTION public.update_auth_email(p_user_id uuid, p_new_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Cannot update another user''s email';
    END IF;

    UPDATE auth.users
    SET email = p_new_email,
        raw_user_meta_data = raw_user_meta_data || jsonb_build_object('email', p_new_email)
    WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_auth_email(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_auth_email(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_auth_email(uuid, text) TO authenticated;
