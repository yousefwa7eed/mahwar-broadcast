-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20260919005116 | name: restore_assign_order_to_provider_acl
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- =============================================================================
-- Drop+recreate in the deadline migration reset this function's ACL to the
-- project-wide function default (which grants anonymous + PUBLIC EXECUTE).
-- Restore the hardened ACL the function had before (authenticated/service_role
-- only), mirroring 20260918070000_revoke_anon_order_lifecycle_rpcs.sql.
REVOKE ALL ON FUNCTION public.assign_order_to_provider(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_order_to_provider(uuid, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.assign_order_to_provider(uuid, uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.assign_order_to_provider(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_order_to_provider(uuid, uuid) TO service_role;
