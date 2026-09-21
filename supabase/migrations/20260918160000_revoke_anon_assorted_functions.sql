-- Migration: revoke anonymous EXECUTE from assorted functions (M4).
-- Date: 2026-09-18
--
-- These were all reachable by the anon key via the default PUBLIC grant.
-- None need to be:
--   * maintenance/cron (service_role only):
--       expire_overdue_orders, flip_provider_availability_at_boundaries,
--       cleanup_stale_broadcast_images
--   * edge-function worker (service_role only, non-secdef):
--       insert_broadcast_notifications
--   * app-called as an authenticated user (anon revoked, authenticated kept):
--       is_provider_available_now, provider_availability_snapshot, server_now

-- service_role-only maintenance
REVOKE ALL ON FUNCTION public.expire_overdue_orders() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.expire_overdue_orders() FROM anon;
REVOKE ALL ON FUNCTION public.expire_overdue_orders() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.expire_overdue_orders() TO service_role;

REVOKE ALL ON FUNCTION public.flip_provider_availability_at_boundaries() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.flip_provider_availability_at_boundaries() FROM anon;
REVOKE ALL ON FUNCTION public.flip_provider_availability_at_boundaries() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.flip_provider_availability_at_boundaries() TO service_role;

REVOKE ALL ON FUNCTION public.cleanup_stale_broadcast_images() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cleanup_stale_broadcast_images() FROM anon;
REVOKE ALL ON FUNCTION public.cleanup_stale_broadcast_images() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_stale_broadcast_images() TO service_role;

REVOKE ALL ON FUNCTION public.insert_broadcast_notifications(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.insert_broadcast_notifications(jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.insert_broadcast_notifications(jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.insert_broadcast_notifications(jsonb) TO service_role;

-- authenticated app RPCs
REVOKE ALL ON FUNCTION public.is_provider_available_now(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_provider_available_now(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_provider_available_now(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.provider_availability_snapshot(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.provider_availability_snapshot(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.provider_availability_snapshot(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.server_now() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.server_now() FROM anon;
GRANT EXECUTE ON FUNCTION public.server_now() TO authenticated;