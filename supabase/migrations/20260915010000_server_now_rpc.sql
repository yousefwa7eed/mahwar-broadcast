-- =============================================================================
-- Server clock for skew-free "time ago" / countdown math on the client.
--
-- Why: relative timestamps ("منذ 5 دقائق", انتهاء المهلة) were computed on the
-- device with DateTime.now(). On older/unsynced devices the system clock is an
-- unreliable anchor, so the same event showed different relative times across
-- devices. The client must anchor "now" to the server clock instead.
--
-- This RPC exposes the database's clock (now()) so Flutter can fetch a UTC
-- server "now" once and base every elapsed-time calculation on it. created_at /
-- respond_deadline are already server-generated (timestamptz, UTC); now the
-- client's "now" side of the subtraction comes from the same clock too.
-- =============================================================================

create or replace function public.server_now()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select now();
$$;

-- Available to any signed-in user; reads nothing, so SECURITY DEFINER is not
-- needed (now() is not table access). No data leaks.
grant execute on function public.server_now() to authenticated;