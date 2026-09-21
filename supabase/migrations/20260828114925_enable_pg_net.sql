-- =============================================================================
-- Reconstructed from the live DB (applied as migration "enable_pg_net").
-- Enables the pg_net extension and exposes the async HTTP helpers so a DB
-- trigger can fire-and-forget an edge function (see order_terminal_cleanup_trigger).
--
-- Extension is installed in the public schema; its functions live in the net
-- schema (http_post etc.). pg_net async requests are executed by the pg_net
-- worker (role pg_net_admin), NOT the calling role, so no auth grants on the
-- helper functions are required for callers to schedule a request.
-- =============================================================================

create extension if not exists pg_net with schema public;
