-- =============================================================================
-- Support ticket email notification — tail of the in-app support inbox (item 10).
--
-- Why: after the mailto hand-off was removed, a support ticket is only stored in
-- public.support_tickets. Nothing reaches the owner's inbox, so the existing
-- Cloudflare rule support@mahwar.app -> Gmail has no mail to forward.
--
-- How: AFTER INSERT trigger posts the ticket id to the send-support-email edge
-- function through pg_net (fire-and-forget), exactly like notify_push. The URL is
-- built from project_ref in the RLS-forced order_event_secret singleton (its
-- edge_url column belongs to send-push-notification and is deliberately NOT used
-- here); the shared ORDER_EVENT_SECRET travels in x-order-event-secret. If the
-- config is missing the trigger skips with a notice, so ticket creation is never
-- blocked by email problems.
--
-- Threat model: SECURITY DEFINER with an empty search_path; the singleton is
-- RLS-enabled + FORCE with zero policies, so only the definer can read it; the
-- function is a trigger function and cannot be called like a normal RPC.
-- =============================================================================

create or replace function public.notify_support_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project_ref text;
  v_secret      text;
  v_edge_url    text;
begin
  select nullif(project_ref, ''), nullif(secret, '')
    into v_project_ref, v_secret
  from public.order_event_secret
  where id = 1;

  v_secret := coalesce(
    v_secret,
    nullif(current_setting('app.settings.order_event_secret', true), '')
  );
  v_project_ref := coalesce(
    v_project_ref,
    nullif(current_setting('app.settings.project_ref', true), '')
  );

  if v_project_ref is null or v_project_ref = '' or v_secret is null or v_secret = '' then
    raise notice 'notify_support_email: skipping — project ref or secret not configured';
    return NEW;
  end if;

  v_edge_url := 'https://' || v_project_ref ||
    '.supabase.co/functions/v1/send-support-email';

  perform net.http_post(
    url     := v_edge_url,
    headers := jsonb_build_object(
      'Content-Type',         'application/json',
      'x-order-event-secret', v_secret
    ),
    body    := jsonb_build_object('ticket_id', NEW.id)
  );

  return NEW;
end;
$$;

drop trigger if exists on_support_ticket_created on public.support_tickets;
create trigger on_support_ticket_created
  after insert on public.support_tickets
  for each row
  execute function public.notify_support_email();
