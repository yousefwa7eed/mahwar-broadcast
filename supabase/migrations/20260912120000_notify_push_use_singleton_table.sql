-- =============================================================================
-- notify_push: make push delivery reliable + remove duplicate trigger.
--
-- Problem 1 (unreliable config): notify_push resolved the edge-function URL
-- and the order-event secret ONLY from per-session settings
-- (app.settings.edge_url / project_ref / order_event_secret). Those settings
-- are never persisted — they only exist if something called set_config in the
-- same session — so for real API traffic the trigger usually found a NULL
-- secret and silently skipped every push notification.
--
-- Solution: fall back to the order_event_secret singleton table (RLS-forced,
-- zero policies, so only the trigger owner — security definer — can read it):
--   secret  -> singleton.secret first (reliable), then session setting.
--   URL     -> app.settings.edge_url, then singleton.edge_url, then
--              app.settings.project_ref / singleton.project_ref built into
--              https://<ref>.supabase.co/functions/v1/send-push-notification.
-- Backfills project_ref so the hosted project works with zero set_config calls.
--
-- Problem 2 (duplicate push): the live DB has TWO AFTER INSERT triggers on
-- notifications — 'notifications_push' (orphan from a pre-repo migration) and
-- 'on_notification_created' (the repo-tracked one) — so every notification
-- fired two FCM pushes. This drops the orphan and keeps a single trigger.
-- =============================================================================

-- 1) Singleton table gains optional URL/project_ref columns (additive).
alter table public.order_event_secret
  add column if not exists edge_url text,
  add column if not exists project_ref text;

-- Backfill the hosted project ref (idempotent; nothing to destroy).
update public.order_event_secret
  set project_ref = 'trgesfzojaoirutkkfcs'
  where id = 1 and (project_ref is null or project_ref = '');

-- 2) Rewrite notify_push with the singleton fallback chain.
create or replace function public.notify_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_edge_url     text;
  v_project_ref  text;
  v_secret       text;
begin
  -- Source of truth: the singleton table (owner-only, RLS-forced).
  select edge_url, project_ref, secret
    into v_edge_url, v_project_ref, v_secret
  from public.order_event_secret
  where id = 1;

  -- Secret precedence: DB table first (reliable), session setting as fallback.
  v_secret := coalesce(
    nullif(v_secret, ''),
    nullif(current_setting('app.settings.order_event_secret', true), '')
  );

  -- URL precedence: session edge_url -> DB edge_url -> session project_ref
  -- -> DB project_ref (each built into the hosted function URL).
  v_edge_url := coalesce(
    nullif(v_edge_url, ''),
    nullif(current_setting('app.settings.edge_url', true), '')
  );
  if v_edge_url is null or v_edge_url = '' then
    v_project_ref := coalesce(
      nullif(v_project_ref, ''),
      nullif(current_setting('app.settings.project_ref', true), '')
    );
    if v_project_ref is not null and v_project_ref != '' then
      v_edge_url := 'https://' || v_project_ref ||
        '.supabase.co/functions/v1/send-push-notification';
    end if;
  end if;

  -- If still unresolvable, skip silently (local dev without settings).
  if v_edge_url is null or v_edge_url = '' or v_secret is null or v_secret = '' then
    raise notice 'notify_push: skipping — edge URL or secret not configured';
    return NEW;
  end if;

  -- Fire-and-forget via pg_net. The push function reads notification data
  -- from the DB by notification_id, so we only pass the id.
  perform net.http_post(
    url     := v_edge_url,
    headers := jsonb_build_object(
      'Content-Type',         'application/json',
      'x-order-event-secret', v_secret
    ),
    body    := jsonb_build_object('notification_id', NEW.id)
  );

  return NEW;
end;
$$;

-- 3) Drop the orphan duplicate trigger (pre-repo migration) if present.
drop trigger if exists notifications_push on public.notifications;

-- 4) Keep exactly one trigger bound to the (new) function.
drop trigger if exists on_notification_created on public.notifications;
create trigger on_notification_created
  after insert on public.notifications
  for each row
  execute function public.notify_push();