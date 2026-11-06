-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20260828132512 | name: expire_pending_orders_cron
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- NOTE: the live pg_cron job for this schedule has since been replaced by
--       public.expire_overdue_orders() (job "expire-overdue-orders-every-minute").
-- =============================================================================
-- =============================================================================
-- جدولة الإلغاء التلقائي للطلبات منتهية مدة الاستجابة (كل دقيقة):
-- expirer → expire-pending-orders (Edge Function، محمي بالسر المشترك).
-- إنشاء الإشعارات والتنظيف (orders_terminal_cleanup) يتم جهة الوظيفة/الـ trigger.
-- =============================================================================
create extension if not exists pg_cron;

select cron.schedule(
  'expire-pending-orders',
  '* * * * *',
  $cron$
  select net.http_post(
    'https://trgesfzojaoirutkkfcs.supabase.co/functions/v1/expire-pending-orders',
    '{}'::jsonb,
    null,
    jsonb_build_object(
      'Content-Type', 'application/json',
      'x-order-event-secret', coalesce(
        (select secret from public.order_event_secret where id = 1),
        ''
      )
    ),
    20000
  );
  $cron$
);
