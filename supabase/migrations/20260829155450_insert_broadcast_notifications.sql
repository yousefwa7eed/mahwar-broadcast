-- =============================================================================
-- Broadcast notifications (owner/super-admin only, invoked via the
-- "send-broadcast-notification" edge function with the shared event secret).
--
-- Instead of a slow row-by-row loop from the app, this is a single set-based
-- INSERT ... SELECT that creates one notifications row (type='broadcast') per
-- registered user in one statement. For thousands of users this is a single
-- efficient statement rather than N round-trips.
--
-- Delivery: the existing AFTER INSERT trigger on public.notifications
-- (notify_push) fires per row and fire-and-forgets the send-push-notification
-- edge function (async via pg_net), so the DB write stays fast and is never
-- blocked by push delivery.
--
-- SECURITY: declared SECURITY INVOKER (not DEFINER). Under the service role
-- (used by the edge function) RLS is bypassed, so the insert works for the
-- owner. Under a normal authenticated user any call is constrained by the
-- notifications RLS INSERT policy (they cannot insert rows for other users),
-- so a regular app user cannot spam every account.
-- =============================================================================

create or replace function public.insert_broadcast_notifications(p_metadata jsonb)
returns integer
language sql
security invoker
set search_path = ''
as $$
  with inserted as (
    insert into public.notifications (user_id, type, metadata)
    select p.id, 'broadcast', p_metadata
    from public.profiles p
    returning 1
  )
  select count(*)::integer from inserted;
$$;
