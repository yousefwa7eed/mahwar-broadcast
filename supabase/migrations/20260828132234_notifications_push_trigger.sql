-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20260828132234 | name: notifications_push_trigger
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- =============================================================================
-- =============================================================================
-- يُطلق إشعار دفع FCM عند كتابة أي إشعار داخل التطبيق (جدول notifications).
-- مصدر واحد لكل أنواع الإشعارات => تزامن جرس / صفحة / جهاز.
-- Fire-and-forget عبر pg_net: فشل الدفع لا يفشل كتابة الإشعار ولا الطلب.
-- =============================================================================
create or replace function public.notify_push()
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
    raise log 'notify_push: missing secret for notification %', new.id;
    return new;
  end if;

  perform net.http_post(
    'https://trgesfzojaoirutkkfcs.supabase.co/functions/v1/send-push-notification',
    jsonb_build_object('notification_id', new.id, 'user_id', new.user_id),
    null,
    jsonb_build_object(
      'Content-Type', 'application/json',
      'x-order-event-secret', v_secret
    ),
    10000
  );

  return new;
exception when others then
  raise log 'notify_push: exception for notification %: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists notifications_push on public.notifications;

create trigger notifications_push
after insert on public.notifications
for each row
execute function public.notify_push();
