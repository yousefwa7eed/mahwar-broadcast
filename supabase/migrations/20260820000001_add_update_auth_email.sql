-- Migration: Add update_auth_email function to sync email to auth.users
-- Date: 2026-08-20

CREATE OR REPLACE FUNCTION public.update_auth_email(p_user_id uuid, p_new_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF p_user_id <> auth.uid() THEN
        RAISE EXCEPTION 'Cannot update another user''s email';
    END IF;

    UPDATE auth.users
    SET email = p_new_email,
        raw_user_meta_data = raw_user_meta_data || jsonb_build_object('email', p_new_email)
    WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_auth_email(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_auth_email(uuid, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_auth_email(uuid, text) TO authenticated;
