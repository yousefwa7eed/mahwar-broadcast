-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20261009165848 | name: revoke_external_execute_national_id_functions
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- =============================================================================
-- These two helpers exist only to be invoked by the BEFORE INSERT trigger and
-- by update_pending_order (both SECURITY DEFINER). They must never be callable
-- through /rest/v1/rpc — Postgres invokes trigger functions natively and the
-- definer RPC is granted separately, so no EXECUTE grants are needed here.
revoke all on function public.enforce_owner_national_id_on_order() from public, anon, authenticated;
revoke all on function public.assert_owner_national_id(uuid) from public, anon, authenticated;

-- Keep the exposed owner entry point granted to signed-in users (as before).
revoke all on function public.update_pending_order(uuid, text, text, text, integer, double precision, double precision, text, text, boolean, boolean) from public, anon;
grant execute on function public.update_pending_order(uuid, text, text, text, integer, double precision, double precision, text, text, boolean, boolean) to authenticated;
