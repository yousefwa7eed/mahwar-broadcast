-- =============================================================================
-- order_live_locations — الموقع اللحظي للعميل أثناء طلب مؤكَّد (Phase 3)
-- =============================================================================
-- الهدف:
--   أثناء الطلب المؤكَّد (status = confirmed) يشارك العميل موقعه اللحظي مع
--   المزوّد المعيَّن فقط، لتتبّع الوصول. لا وجود لهذا الجدول خارج تلك النافذة:
--   الصف يُنشأ عند أول تحديث من المالك، ويُحذف تلقائياً بمجرد خروج الطلب من
--   confirmed (اكتمال/إلغاء/رفض)، إضافة إلى حذف احتياطي يومي.
--
-- نموذج التهديد (لماذا هذا الشكل تحديداً):
--   * الموقع اللحظي بيانات حرجة: من يقرؤه يعرف أين يوجد العميل الآن. لذلك
--     لا تُمنح الكتابة المباشرة لأي دور عميل — كل الكتابة عبر
--     update_order_location() بهوية الجلسة، والقراءة بسياسة SELECT واحدة
--     تقتصر على طرفي الطلب المؤكَّد فقط (المالك والمزوّد المعيَّن).
--   * FORCE RLS يمنع حتى مالك الجدول من تجاوز السياسات صدفةً خارج دوال
--     SECURITY DEFINER المقصودة.
--   * دالة التحديث لا تكشف وجود الطلب لغير مالكه: الاستعلام يجمع الوجود
--     والملكية معاً، وأي فشل يعطي نفس الخطأ ORDER_NOT_FOUND_OR_NOT_OWNER.
--   * حدّ 5 ثوانٍ بين الكتابات يمنع إغراق الجدول/البثّ من عميل مخترق أو حلقة
--     إرسال خاطئة، والتجاهل صامت حتى لا يتحول تأخير الشبكة إلى أخطاء ظاهرة.
--   * منشور في supabase_realtime ليصل UPDATE إلى المزوّد، مع بقاء RLS هو
--     الحاكم على من يستطيع الاشتراك فعلياً.
--
-- هذه المرحلة لا تكتب عميل الموقع اللحظي: الملف قابل للمراجعة والتطبيق فقط.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1) الجدول: صف واحد لكل طلب (المفتاح الأساسي = order_id).
--    القيود هنا حزام أمان ثانٍ بعد تحقق الدالة، وتحمي من كتابة service_role
--    أو صيانة يدوية بقيم خارج النطاق الجغرافي.
-- -----------------------------------------------------------------------------
create table public.order_live_locations (
  order_id   uuid primary key references public.orders(id) on delete cascade,
  latitude   double precision not null check (latitude between -90 and 90),
  longitude  double precision not null check (longitude between -180 and 180),
  accuracy   double precision check (accuracy is null or accuracy >= 0),
  updated_at timestamptz not null default now()
);

comment on table public.order_live_locations is
  'الموقع اللحظي لعميل طلب مؤكَّد فقط. صف واحد لكل طلب، يُكتب حصراً عبر update_order_location() ويُحذف تلقائياً عند خروج الطلب من confirmed.';
comment on column public.order_live_locations.accuracy is
  'دقة القياس بالأمتار كما أرسلها الجهاز؛ NULL يعني غير معروفة.';

-- -----------------------------------------------------------------------------
-- 2) RLS مفعّلة + FORCE، وسياسة قراءة واحدة لطرفي الطلب المؤكَّد.
--    لا توجد سياسات INSERT/UPDATE/DELETE: حتى لو مُنح دور ما صلاحية جدولية،
--    RLS بلا سياسة كتابة ترفض كل تعديل مباشر.
-- -----------------------------------------------------------------------------
alter table public.order_live_locations enable row level security;
alter table public.order_live_locations force row level security;

create policy "Participants read confirmed order live location"
  on public.order_live_locations
  for select
  to authenticated
  using (
    exists (
      select 1
        from public.orders o
       where o.id = order_live_locations.order_id
         and (
           o.car_owner_id = auth.uid()
           or (o.provider_id = auth.uid() and o.status = 'confirmed')
         )
    )
  );

-- لا صلاحيات جدولية افتراضية من Supabase تُترك مفتوحة: نلغي الكل ثم نمنح
-- القراءة لـ authenticated وحدها (سياسة RLS أعلاه تحدّد أي الصفوف).
revoke all on table public.order_live_locations from public, anon, authenticated;
grant select on table public.order_live_locations to authenticated;

-- -----------------------------------------------------------------------------
-- 3) النشر في Realtime: بدونها لا يصل UPDATE للمزوّد. الكتلة idempotent حتى
--    لا تفشل إن كان الجدول مضافاً مسبقاً (نمط 20260916150000).
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'order_live_locations'
  ) then
    execute 'alter publication supabase_realtime add table public.order_live_locations';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4) update_order_location: مسار الكتابة الوحيد.
--    * SECURITY DEFINER + search_path = '' (كل شيء مؤهَّل بالمخطط).
--    * الهوية من auth.uid() فقط، والملكية تُفحص في نفس استعلام الوجود.
--    * الطلب يجب أن يكون confirmed؛ أي حالة أخرى = ORDER_NOT_ACTIVE.
--    * تحقق نطاقات الإحداثيات والدقة.
--    * تجاهل صامت إن مرّ أقل من 5 ثوانٍ على آخر تحديث.
--    * Upsert ذرّي: صف واحد لكل طلب.
-- -----------------------------------------------------------------------------
create or replace function public.update_order_location(
  p_order_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy double precision default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid    uuid := auth.uid();
  v_status public.order_status;
  v_last   timestamptz;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- الوجود والملكية معاً: غير المالك يحصل على نفس الخطأ سواء وُجد الطلب أم لا،
  -- فلا يمكن استكشاف أرقام الطلبات عبر فروق رسائل الخطأ.
  select o.status
    into v_status
    from public.orders o
   where o.id = p_order_id
     and o.car_owner_id = v_uid;

  if not found then
    raise exception 'ORDER_NOT_FOUND_OR_NOT_OWNER';
  end if;

  if v_status <> 'confirmed' then
    raise exception 'ORDER_NOT_ACTIVE';
  end if;

  if p_lat is null or p_lat < -90 or p_lat > 90 then
    raise exception 'INVALID_LATITUDE';
  end if;

  if p_lng is null or p_lng < -180 or p_lng > 180 then
    raise exception 'INVALID_LONGITUDE';
  end if;

  if p_accuracy is not null and p_accuracy < 0 then
    raise exception 'INVALID_ACCURACY';
  end if;

  -- حدّ المعدل: التجاهل الصامت مقصود. العميل يرسل دورياً، والخطأ هنا سيظهر
  -- كضجيج بلا فائدة؛ القيمة الأحدث تصل في المحاولة التالية بعد 5 ثوانٍ.
  select l.updated_at
    into v_last
    from public.order_live_locations l
   where l.order_id = p_order_id;

  if v_last is not null and now() - v_last < interval '5 seconds' then
    return;
  end if;

  insert into public.order_live_locations (order_id, latitude, longitude, accuracy, updated_at)
  values (p_order_id, p_lat, p_lng, p_accuracy, now())
  on conflict (order_id) do update
    set latitude   = excluded.latitude,
        longitude  = excluded.longitude,
        accuracy   = excluded.accuracy,
        updated_at = excluded.updated_at;
end;
$function$;

comment on function public.update_order_location(uuid, double precision, double precision, double precision) is
  'Owner-only live-location upsert for a confirmed order. Validates ranges, silently ignores writes within 5 s of the previous one, and does not reveal order existence to non-owners.';

revoke all on function public.update_order_location(uuid, double precision, double precision, double precision) from public, anon;
grant execute on function public.update_order_location(uuid, double precision, double precision, double precision) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) تنظيف عند خروج الطلب من confirmed.
--    AFTER UPDATE OF status على orders، مع WHEN حتى لا يعمل الـ trigger على
--    تحديثات لا تغيّر الحالة. الدالة SECURITY DEFINER وبلا search_path،
--    وEXECUTE مسحوبة من كل أدوار العميل: تُستدعى من الـ trigger فقط.
-- -----------------------------------------------------------------------------
create or replace function public.clear_order_live_location()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  delete from public.order_live_locations
   where order_id = new.id;
  return new;
end;
$function$;

comment on function public.clear_order_live_location() is
  'Trigger-only: deletes the live-location row when an order leaves confirmed (completed, cancelled, rejected…).';

revoke all on function public.clear_order_live_location() from public, anon, authenticated;

drop trigger if exists trg_orders_clear_live_location on public.orders;
create trigger trg_orders_clear_live_location
  after update of status on public.orders
  for each row
  when (new.status is distinct from old.status and new.status <> 'confirmed')
  execute function public.clear_order_live_location();

-- -----------------------------------------------------------------------------
-- 6) شبكة أمان يومية عبر pg_cron.
--    pg_cron مفعّل فعلياً على المشروع الحي (تحقق للقراءة فقط بتاريخ 2026-10-27:
--    extversion 1.6.4، و`cron.job` يحتوي مهام قائمة). المهمة تحذف أي صف أقدم
--    من يوم — لا يُفترض وجوده بعد الـ trigger، لكنها تغطي حالات سباق أو صيانة.
--    cron.schedule بالاسم idempotent ويستبدل المهمة إن كانت موجودة.
-- -----------------------------------------------------------------------------
select cron.schedule(
  'purge-order-live-locations',
  '15 4 * * *',
  $$delete from public.order_live_locations where updated_at < now() - interval '1 day';$$
);

-- =============================================================================
-- VERIFICATION (read-only; تنفيذ يدوي بعد التطبيق)
-- =============================================================================
--
-- (a) الجدول والسياسات والصلاحيات:
-- select relrowsecurity, relforcerowsecurity
--   from pg_class where oid = 'public.order_live_locations'::regclass;
-- -- expect: true, true
--
-- select polname, polcmd from pg_policy
--  where polrelid = 'public.order_live_locations'::regclass;
-- -- expect: سياسة SELECT واحدة فقط
--
-- select grantee, privilege_type
--   from information_schema.role_table_grants
--  where table_schema = 'public' and table_name = 'order_live_locations'
--  order by grantee, privilege_type;
-- -- expect: authenticated = SELECT فقط
--
-- (b) الدالة والتوقيع:
-- select proname, pg_get_function_identity_arguments(oid) as args,
--        prosecdef, proconfig
--   from pg_proc
--  where oid in ('public.update_order_location(uuid,double precision,double precision,double precision)'::regprocedure,
--                'public.clear_order_live_location()'::regprocedure);
-- -- expect: prosecdef = true، proconfig = {search_path=}
--
-- (c) النشر في Realtime:
-- select * from pg_publication_tables
--  where pubname = 'supabase_realtime' and tablename = 'order_live_locations';
--
-- (d) مهمة cron:
-- select jobid, jobname, schedule, command, active
--   from cron.job where jobname = 'purge-order-live-locations';
