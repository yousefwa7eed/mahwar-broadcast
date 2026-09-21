-- =============================================================================
-- notify_push trigger: after INSERT on public.notifications, fire-and-forget
-- the send-push-notification edge function via pg_net so the user gets a
-- real system push notification (FCM).
--
-- Requires: pg_net extension (already enabled in a prior migration).
-- =============================================================================

-- 1) Helper function: reads the edge-function URL from a Postgres setting
--    (avoids hardcoding the project ref). Falls back to the well-known pattern.
create or replace function public.notify_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_edge_url text;
  v_secret   text;
begin
  -- Build the edge-function URL from the current Supabase project ref.
  -- This works both locally (localhost) and on the hosted platform.
  -- Setting is set per-session; fallback to env var if not set.
  v_edge_url := current_setting('app.settings.edge_url', true);
  if v_edge_url is null or v_edge_url = '' then
    v_edge_url := current_setting('app.settings.project_ref', true);
    if v_edge_url is not null and v_edge_url != '' then
      v_edge_url := 'https://' || v_edge_url || '.supabase.co/functions/v1/send-push-notification';
    end if;
  end if;

  v_secret := current_setting('app.settings.order_event_secret', true);

  -- If we still can't resolve the URL, skip silently (local dev without settings).
  if v_edge_url is null or v_edge_url = '' or v_secret is null or v_secret = '' then
    raise notice 'notify_push: skipping — edge URL or secret not configured';
    return NEW;
  end if;

  -- Fire-and-forget via pg_net. The push function reads notification data
  -- from the DB by notification_id, so we only pass the id.
  perform net.http_post(
    url     := v_edge_url,
    headers := jsonb_build_object(
      'Content-Type',          'application/json',
      'x-order-event-secret',  v_secret
    ),
    body    := jsonb_build_object('notification_id', NEW.id)
  );

  return NEW;
end;
$$;

-- 2) Attach trigger to notifications table (AFTER INSERT, per-row).
-- Uses WHEN clause to skip if the notification already has a 'push_sent' flag
-- (future use) — for now it fires on every insert.
drop trigger if exists on_notification_created on public.notifications;

create trigger on_notification_created
  after insert on public.notifications
  for each row
  execute function public.notify_push();
