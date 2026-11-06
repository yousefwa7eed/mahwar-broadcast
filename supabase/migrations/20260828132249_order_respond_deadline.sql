-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20260828132249 | name: order_respond_deadline
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- =============================================================================
-- =============================================================================
-- مدة استجابة المزوّد (3 دقائق من لحظة إسناد الطلب له):
--  - عمود respond_deadline على orders.
--  - عند إسناد طلب pending لمزوّد (أو إعادة إسناده لمزوّد آخر) تُحدَّث المهلة
--    بوساطة BEFORE trigger ليكون بلا استثناءات (أي مسار تغيير provider_id).
--  - بمجرد خروج الطلب من حالة pending تُمسح المهلة.
-- الإلغاء التلقائي بعد المدة يتم عبر Edge Function + pg_cron (migration تالية).
-- =============================================================================
alter table public.orders add column if not exists respond_deadline timestamptz;

create or replace function public.set_respond_deadline()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'pending' and new.provider_id is not null
     and old.provider_id is distinct from new.provider_id then
    new.respond_deadline := now() + interval '3 minutes';
  end if;

  if new.status <> 'pending' then
    new.respond_deadline := null;
  end if;

  return new;
end;
$$;

drop trigger if exists order_respond_deadline on public.orders;

create trigger order_respond_deadline
before insert or update of provider_id, status on public.orders
for each row
execute function public.set_respond_deadline();
