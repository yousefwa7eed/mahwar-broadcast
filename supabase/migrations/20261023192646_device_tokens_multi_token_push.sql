-- =============================================================================
-- device_tokens — توكنات دفع لكل (مستخدم، جهاز) بدل عمود واحد في profiles
-- =============================================================================
-- المشكلة (مثبتة ببيانات حية من net._http_response):
--   النموذج القديم يخزّن توكن FCM واحداً في profiles.fcm_token، ويحميه
--   trigger «profiles_single_device_owner» يمسح التوكن و device_id من كل
--   الحسابات الأخرى التي تشترك في نفس الجهاز. النتيجة على جهاز واحد يتناوب
--   عليه حسابان (هاتف الورشة، أو حساب العميل وحساب المزوّد على جهاز المطوّر):
--   آخر من سجّل الدخول فقط يصله الدفع، وإشعارات الباقي تُقصى في الخادم
--   بـ skipped:"no_token" — فشل صامت بالكامل لأن صف notifications يُكتب بنجاح
--   ويبدو كل شيء سليماً من طرف قاعدة البيانات.
--   ويضاف إليه أن الخروج كان يمسح التوكن من profiles ويحذفه من FCM نفسه
--   (FirebaseMessaging.deleteToken)، فينقطع الدفع عن الحساب نهائياً.
--
-- النموذج الجديد:
--   * صف لكل (user_id, device_id). توكن FCM يخص «تثبيتاً» واحداً لا حساباً،
--     لذا قد يتكرر نفس التوكن في صفوف عدة مستخدمين على نفس الجهاز — وهذا
--     مقصود: قرار المالك (2026-10-22) أن يبقى التوكن بعد الخروج حتى تصل
--     تنبيهات الحسابات الأخرى المرتبطة بنفس الجهاز.
--   * الكتابة حصراً عبر register_device_token() بهوية الجلسة (auth.uid())،
--     فلا يستطيع مستخدم إنشاء أو تعديل صف مستخدم آخر = لا اختطاف إشعارات.
--   * تنظيف التوكنات الميتة في الخادم عند UNREGISTERED، لا عند الخروج.
--
-- نطاق هذه المرحلة: إضافي ما أمكن. نُنشئ الجدول والـ RPC ونُبطل سرقة التوكن،
--   ونُبقي عمودي profiles.fcm_token/device_id (معلَّمين كمُهملَين) حتى تنتهي
--   النسخ القديمة المثبّتة، ثم يُحذفان في migration لاحقة.
--   ملاحظة تشغيلية: بعد نشر send-push-notification الجديدة تتوقف النسخ القديمة
--   عن استقبال الدفع (تكتب في profiles والجديد يقرأ device_tokens) حتى تحديثها.
-- =============================================================================

-- 1) الجدول -------------------------------------------------------------------
create table if not exists public.device_tokens (
  user_id      uuid         not null references auth.users(id) on delete cascade,
  device_id    text         not null,
  token        text         not null,
  -- معلوماتي للتشخيص فقط (الدفع عبر FCM HTTP v1 لا يفرّق بين المنصات هنا).
  platform     text         not null default 'android'
               check (platform in ('android', 'ios', 'web')),
  last_seen_at timestamptz  not null default now(),
  created_at   timestamptz  not null default now(),
  -- جهاز واحد لكل مستخدم = صف واحد. نفس التوكن قد يظهر لعدة user_id (مقصود).
  primary key (user_id, device_id)
);

comment on table public.device_tokens is
  'توكنات FCM لكل (مستخدم، جهاز). بديل profiles.fcm_token الأحادي. الكتابة عبر register_device_token() فقط، والقراءة من send-push-notification بمفتاح الخدمة.';

-- 2) RLS: مفعّلة + FORCE وبلا أي سياسة، على نمط الجداول المقفولة في المشروع
--    (admins / admin_audit_log). لا يحتاج العميل قراءة صفوفه، فمنع الوصول المباشر
--    يقلّص السطح: أي قراءة/كتابة تتم إما عبر RPC (بهوية المالك postgres وله
--    BYPASSRLS) أو عبر مفتاح الخدمة داخل دالة الحافة.
alter table public.device_tokens enable row level security;
alter table public.device_tokens force row level security;

revoke all on table public.device_tokens from public, anon, authenticated;
-- دالة الحافة (service_role) تقرأ التوكنات وتحذف الميت منها.
grant select, delete on table public.device_tokens to service_role;

-- 3) RPC التسجيل --------------------------------------------------------------
create or replace function public.register_device_token(
  p_token     text,
  p_device_id text,
  p_platform  text default 'android'
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid      uuid := auth.uid();
  v_token    text := nullif(btrim(coalesce(p_token, '')), '');
  v_device   text := nullif(btrim(coalesce(p_device_id, '')), '');
  v_platform text := lower(btrim(coalesce(p_platform, 'android')));
begin
  -- الهوية من الجلسة وحدها، أبداً من معامل: لا يمكن تسجيل توكن لحساب آخر،
  -- وهذا ما يمنع تحويل إشعارات ضحية إلى جهاز المهاجم.
  if v_uid is null then
    raise exception 'register_device_token: no session';
  end if;

  -- تحقّق شكلي رخيص يوقف القمامة قبل أن تستقر في الجدول. الرسائل بلا بادئة
  -- «CODE:» عن قصد: هذا المسار لا يُعرض للمستخدم إطلاقاً (العميل يبتلع الخطأ
  -- ويكمل حتى لا يفشل تسجيل الدخول بسبب الدفع)، فلا مفتاح ترجمة له.
  if v_token is null or length(v_token) < 20 or length(v_token) > 4096 then
    raise exception 'register_device_token: token length out of range';
  end if;
  if v_device is null or length(v_device) < 8 or length(v_device) > 128 then
    raise exception 'register_device_token: device_id length out of range';
  end if;
  if v_platform not in ('android', 'ios', 'web') then
    v_platform := 'android';
  end if;

  insert into public.device_tokens (user_id, device_id, token, platform, last_seen_at)
  values (v_uid, v_device, v_token, v_platform, now())
  on conflict (user_id, device_id) do update
    set token        = excluded.token,
        platform     = excluded.platform,
        last_seen_at = now();

  -- نفس التوكن تحت device_id آخر لنفس المستخدم = تثبيت سابق أو محو التخزين
  -- الآمن. نُبقى الصف الحي وحده حتى لا نرسل إشعاراً واحداً مرتين للجهاز نفسه.
  delete from public.device_tokens
   where user_id   = v_uid
     and token     = v_token
     and device_id <> v_device;

  -- سقف دفاعي: الـ RPC عام يستدعيه أي مستخدم مسجّل، فبدون سقف يمكن تضخيم
  -- الجدول (ومعه تكلفة و زمن الدفع) بتمرير device_id عشوائية. نُبقى أحدث 5.
  with keep as (
    select device_id
      from public.device_tokens
     where user_id = v_uid
     order by last_seen_at desc, device_id
     limit 5
  )
  delete from public.device_tokens dt
   where dt.user_id   = v_uid
     and dt.device_id not in (select device_id from keep);
end;
$function$;

revoke all on function public.register_device_token(text, text, text) from public, anon;
grant execute on function public.register_device_token(text, text, text) to authenticated;

-- 4) ترحيل ما هو موجود --------------------------------------------------------
-- platform غير معروف للصفوف القديمة؛ 'android' هو الواقع الفعلي للتطبيق.
-- device_id الغائب يُستبدل بمعرّف ثابت مشتق من المستخدم حتى لا يفشل القيد.
insert into public.device_tokens (user_id, device_id, token, platform, last_seen_at)
select p.id,
       coalesce(nullif(btrim(p.device_id), ''), 'legacy-' || p.id::text),
       btrim(p.fcm_token),
       'android',
       now()
  from public.profiles p
 where p.fcm_token is not null
   and btrim(p.fcm_token) <> ''
on conflict (user_id, device_id) do nothing;

-- 5) إيقاف سرقة التوكن ---------------------------------------------------------
-- الـ trigger كان يمسح التوكن من كل الحسابات الأخرى على نفس الجهاز، وهو سبب
-- العطل الحالي. مع device_tokens أصبح تعدد الحسابات على الجهاز مقصوداً،
-- فيُسقط الـ trigger ودالته معاً.
drop trigger if exists profiles_single_device_owner on public.profiles;
drop function if exists public.single_device_owner();

-- 6) تعليم العمودين القديمين كمُهملَين (يُحذفان في مرحلة لاحقة) ----------------
comment on column public.profiles.fcm_token is
  'DEPRECATED — مصدر توكنات الدفع الآن public.device_tokens. لم يعد يُقرأ من أي كود. يُحذف مع device_id في migration لاحقة.';
comment on column public.profiles.device_id is
  'DEPRECATED — انظر profiles.fcm_token. لم يعد يُقرأ من أي كود.';
