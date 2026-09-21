-- Migration: LOW/hygiene hardening pass.
-- Date: 2026-09-18
--
-- 1) Pin search_path on helper functions flagged by advisor
--    `function_search_path_mutable`. All these are SECURITY INVOKER; setting an
--    empty search_path silences the lint. pg_catalog is always searched
--    implicitly, and cross-schema calls are already schema-qualified.
--
-- 2) Revoke anonymous EXECUTE from SECURITY DEFINER functions that are never
--    meant to be called by the anon key:
--      * trigger / event-trigger functions (return `trigger`/`event_trigger`;
--        not even exposed by PostgREST, but the default PUBLIC grant still
--        shows up as anon-executable). `authenticated` + `service_role` are
--        re-granted so any runtime EXECUTE check on trigger firing stays
--        satisfied; the auth.users triggers also get `supabase_auth_admin`.
--      * real RPCs `delete_user_account` (unused: the delete-account edge
--        function uses service_role `cleanup_user_data`),
--        `get_nearest_providers`, `get_provider_details` (authenticated-only
--        call sites; anon was already removed from `public_provider_profiles`
--        in C2).
--    `get_email_by_phone` is intentionally left anon-executable (H5 throttle).

-- 1) search_path pinning
ALTER FUNCTION public.update_updated_at_column() SET search_path = '';
ALTER FUNCTION public.normalize_phone(text) SET search_path = '';
ALTER FUNCTION public.fold_phone_digits(text) SET search_path = '';

-- 2a) trigger / event-trigger helpers: drop anon, keep authenticated + service_role
DO $$
DECLARE
  fn text;
  sigs text[] := ARRAY[
    'guard_role_immutable()',
    'handle_new_user()',
    'handle_user_email_update()',
    'notify_order_terminal_cleanup()',
    'notify_push()',
    'sync_auth_role_from_profile()',
    'orders_apply_cancel_prefs()',
    'rls_auto_enable()'
  ];
BEGIN
  FOREACH fn IN ARRAY sigs LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC', fn);
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM anon', fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO service_role', fn);
  END LOOP;
END $$;

-- auth.users triggers also fire as the auth admin during signup / email change
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.handle_user_email_update() TO supabase_auth_admin;

-- 2b) RPCs: drop anon, keep authenticated + service_role
REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_account() FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO service_role;

REVOKE ALL ON FUNCTION public.get_nearest_providers(double precision, double precision, text, double precision) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_nearest_providers(double precision, double precision, text, double precision) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_nearest_providers(double precision, double precision, text, double precision) TO authenticated;

REVOKE ALL ON FUNCTION public.get_provider_details(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_provider_details(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_provider_details(uuid) TO authenticated;