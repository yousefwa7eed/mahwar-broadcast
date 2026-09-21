-- =============================================================================
-- Reconstructed from the live DB (applied as migration "order_terminal_cleanup_trigger").
-- When an order transitions to a terminal status (completed / cancelled) this
-- trigger fire-and-forgets the "delete-order-attachments" edge function (via
-- pg_net) so attached storage objects are cleaned up asynchronously. A failure
-- to clean up never blocks the order status update.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) order_event_secret: single-row table holding the shared secret used to
--    authorize the cleanup webhook call. RLS is enabled with no policies, so
--    only the owning role / SECURITY DEFINER functions can read it.
--    NOTE: the secret VALUE is not committed (credential); seed it via the
--    dashboard/psql after applying, matching the edge function's expectation.
-- ---------------------------------------------------------------------------
create table if not exists public.order_event_secret (
  id          integer primary key,
  secret      text,
  updated_at  timestamptz
);

alter table public.order_event_secret
  add constraint order_event_secret_singleton check (id = 1);

alter table public.order_event_secret enable row level security;

-- ---------------------------------------------------------------------------
-- 2) notify_order_terminal_cleanup(): reads the secret and POSTs to the
--    delete-order-attachments edge function. Uses net.http_post so it is async
--    (fire-and-forget); any exception is caught and only logged.
-- ---------------------------------------------------------------------------
create or replace function public.notify_order_terminal_cleanup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
begin
  select s.secret into v_secret
  from public.order_event_secret s
  where s.id = 1;

  if v_secret is null or v_secret = '' then
    raise log 'order_terminal_cleanup: missing event secret for order %', new.id;
    return new;
  end if;

  perform net.http_post(
    'https://trgesfzojaoirutkkfcs.supabase.co/functions/v1/delete-order-attachments',
    jsonb_build_object('order_id', new.id, 'status', new.status),
    null,
    jsonb_build_object(
      'Content-Type', 'application/json',
      'x-order-event-secret', v_secret
    ),
    10000
  );

  raise log 'order_terminal_cleanup: order % became %, cleanup requested', new.id, new.status;
  return new;
exception when others then
  -- do not let cleanup failure cancel the status update; log and continue.
  raise log 'order_terminal_cleanup: exception for order %: %', new.id, sqlerrm;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Trigger on orders (only fires on status change to a terminal value).
-- ---------------------------------------------------------------------------
drop trigger if exists order_terminal_cleanup on public.orders;
create trigger order_terminal_cleanup
  after update of status on public.orders
  for each row
  when (new.status is distinct from old.status
        and new.status = any (array['completed'::public.order_status,
                                    'cancelled'::public.order_status]))
  execute function public.notify_order_terminal_cleanup();
