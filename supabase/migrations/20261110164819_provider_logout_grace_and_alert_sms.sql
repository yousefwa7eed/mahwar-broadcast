-- =====================================================================
-- provider_logout_grace_and_alert_sms
-- (applied as 20261110164819)
--
-- Item 1 — إيقاف نشاط المزوّد:
--   * providers.logged_out_at يُكتب فقط عند إغلاق آخر جلسة حيّة.
--   * الأهلية تمنح نافذة ساعتين بعد آخر خروج، ثم تسقط تلقائيًا بلا أي
--     كتابة دورية (الشرط يُقرأ لحظة الاستعلام).
--   * الخروج من جهاز واحد لا يمسّ بقية الأجهزة (العميل سيتحول إلى
--     SignOutScope.local — تغيير عميل لا علاقة له بقاعدة البيانات).
--   * العدّ من auth.sessions يتجاوز صلاحيات المستخدم — لذا الدوال
--     SECURITY DEFINER مملوكة لـ postgres مع search_path='' بالكامل.
--
-- Item 2 — SMS للمزوّد الغائب:
--   * جدول سجل مستقل (لا نلمس sms_send_logs: otp_hash NOT NULL وخاص بـ OTP).
--   * رسالة واحدة لكل طلب محفوظة بفهرس فريد جزئي على (order_id)، مع صف
--     حجز result='sending' يمنع إرسالين متزامنين؛ الفشل يحوّل الصف إلى
--     'failed' فيُسمح بإعادة المحاولة (قرار المنتج: الفاشلة لا تُحرق الشهر).
--   * الحصة الشهرية للمزوّد = رسالة ناجحة واحدة/شهر (شهر القاهرة).
--   * سقف يومي مجمّع من sms_cap_config لحماية باقة ZADX، مستقل عن OTP.
--
-- RLS: الجدول مفعّل + FORCE + صفر سياسات، وسحب كل الصلاحيات عن
-- anon/authenticated — القراءة/الكتابة فقط عبر دالة الحالة و Edge Function
-- بمفتاح الخدمة. لا نضيف logged_out_at إلى public_provider_profiles لأن
-- تلك الـ view (مالكها postgres بلا security_invoker) ممنوحة لأي زائر.
-- =====================================================================

-- 1) عمود الخروج
----------------------------------------------------------------------
alter table public.providers
  add column if not exists logged_out_at timestamptz;

comment on column public.providers.logged_out_at is
  'وقت إغلاق آخر جلسة للمزوّد (NULL = لم يسجّل خروجًا بعد). الأهلية تسقط تلقائيًا بعد ساعتين من هذا الوقت.';

-- 2) معاينة الخروج: هل هذه آخر جلسة حيّة؟
----------------------------------------------------------------------
create or replace function public.provider_logout_preview()
returns table (is_last_session boolean, active_sessions integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_role  text;
  v_count integer;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'provider' then
    raise exception 'NOT_PROVIDER';
  end if;

  -- الجلسات المنتهية (not_after) لا تُحتسب: لا تُبقي المزوّد "نشطًا" وهميًا.
  select count(*)::integer into v_count
    from auth.sessions s
   where s.user_id = v_uid
     and (s.not_after is null or s.not_after > now());

  return query select v_count <= 1, v_count;
end;
$$;

-- 3) تسجيل الخروج الفعلي: نعيد العدّ هنا (حماية من سباق بين الحوار والتأكيد)
----------------------------------------------------------------------
create or replace function public.provider_mark_logged_out()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_role  text;
  v_count integer;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'provider' then
    raise exception 'NOT_PROVIDER';
  end if;

  select count(*)::integer into v_count
    from auth.sessions s
   where s.user_id = v_uid
     and (s.not_after is null or s.not_after > now());

  -- جهاز آخر ما زال مسجّلًا: لا تغيير على الإطلاق.
  if v_count > 1 then
    return false;
  end if;

  update public.providers
     set logged_out_at = now()
   where id = v_uid;

  if not found then
    raise exception 'PROVIDER_NOT_FOUND';
  end if;

  return true;
end;
$$;

-- 4) عودة النشاط عند فتح رئيسية المزوّد أو العودة للمقدمة
----------------------------------------------------------------------
create or replace function public.provider_mark_active()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_role text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'provider' then
    raise exception 'NOT_PROVIDER';
  end if;

  update public.providers
     set logged_out_at = null
   where id = v_uid
     and logged_out_at is not null;
end;
$$;

-- 5) الأهلية: نافذة الساعتين بعد آخر خروج
----------------------------------------------------------------------
create or replace function public.is_provider_eligible_for_order(p_provider_id uuid, p_service_type_id text, p_owner_lat double precision, p_owner_lng double precision, p_max_distance_meters double precision DEFAULT 50000)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.public_provider_profiles v
    where v.provider_id = p_provider_id
      and v.is_online = true
      and (p_service_type_id is null or v.services @> array[p_service_type_id])
      and public.earth_distance(
            public.ll_to_earth(p_owner_lat, p_owner_lng),
            public.ll_to_earth(v.latitude, v.longitude)
          ) <= p_max_distance_meters
      -- نافذة السماح بعد آخر خروج آخر جلسة: 2 ساعات. صف providers مفقود
      -- (لا يمكن حدوثه نظريًا لأن الـ view مبنية عليه) يُعامل كغير مؤهل.
      and coalesce(
            (select case
                      when pr.logged_out_at is null then true
                      else now() - pr.logged_out_at < interval '2 hours'
                    end
               from public.providers pr
              where pr.id = p_provider_id),
            false)
  );
$$;

-- 6) سجل تنبيهات SMS للمزوّدين
----------------------------------------------------------------------
create table if not exists public.provider_alert_sms_log (
  id          bigint generated always as identity primary key,
  provider_id uuid not null references public.providers(id) on delete cascade,
  order_id    uuid not null references public.orders(id) on delete cascade,
  phone_e164  text not null,
  -- sending: حجز ذرّي قبل نداء ZADX | sent/failed: نتيجة المحاولة
  result      text not null default 'sending'
              check (result in ('sending', 'sent', 'failed')),
  error_code  text,
  sent_at     timestamptz not null default now()
);

comment on table public.provider_alert_sms_log is
  'محاولات تنبيه SMS للمزوّد الغائب. رسالة ناجحة واحدة لكل طلب (فهرس جزئي)، وحصة واحدة/مزوّد/شهر ناجحة. لا يُقرأ من العميل — RLS FORCE بلا سياسات و service_role فقط.';

-- رسالة واحدة لكل طلب:
--  * 'sending' يحجز الطلب قبل الإرسال فيمنع إرسالين متزامنين.
--  * 'sent' يمنع أي محاولة ثانية بعد النجاح.
--  * 'failed' خارج الفهرس عمدًا: المحاولة الفاشلة يمكن إعادتها (لا تُحرق
--    حصة المزوّد الشهري، وتُحتسب فقط في السقف اليومي المجمّع).
create unique index if not exists provider_alert_sms_log_one_per_order_idx
  on public.provider_alert_sms_log (order_id)
  where result in ('sending', 'sent');

create index if not exists provider_alert_sms_log_provider_sent_idx
  on public.provider_alert_sms_log (provider_id, sent_at desc);

create index if not exists provider_alert_sms_log_sent_at_idx
  on public.provider_alert_sms_log (sent_at);

alter table public.provider_alert_sms_log enable row level security;
alter table public.provider_alert_sms_log force row level security;

revoke all on table public.provider_alert_sms_log from public, anon, authenticated;
revoke all on sequence public.provider_alert_sms_log_id_seq from public, anon, authenticated;
grant select, insert, update on table public.provider_alert_sms_log to service_role;
grant usage, select on sequence public.provider_alert_sms_log_id_seq to service_role;

-- 7) السقف اليومي المجمّع (مستقل عن سقوف OTP في نفس الجدول)
----------------------------------------------------------------------
insert into public.sms_cap_config (key, value, note)
values (
  'provider_alert_global_per_day',
  50,
  'Max provider-alert SMS across all providers per Cairo day. Independent of OTP caps; protects the ZADX package.'
)
on conflict (key) do nothing;

-- 8) حالة اقتراح التنبيه لشاشة تتبع العميل (بعد 30 ثانية)
----------------------------------------------------------------------
create or replace function public.order_provider_alert_status(p_order_id uuid)
returns table (is_logged_out boolean, can_alert boolean, reason text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid          uuid := auth.uid();
  v_owner_id     uuid;
  v_provider_id  uuid;
  v_status       text;
  v_logged_out   timestamptz;
  v_monthly_used integer;
  v_daily_cap    integer;
  v_daily_used   integer;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select o.car_owner_id, o.provider_id, o.status::text
    into v_owner_id, v_provider_id, v_status
    from public.orders o
   where o.id = p_order_id;

  if v_owner_id is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  -- الهوية من التوثيق فقط: لا يكشف حالة مزوّد لغير صاحب الطلب.
  if v_owner_id <> v_uid then
    raise exception 'NOT_OWNER';
  end if;

  if v_provider_id is null then
    return query select false, false, 'provider_active';
    return;
  end if;

  select pr.logged_out_at into v_logged_out
    from public.providers pr
   where pr.id = v_provider_id;

  -- المزوّد نشط (لم يسجّل خروجًا أو انقضت نافذة الساعتين).
  if v_logged_out is null or now() - v_logged_out >= interval '2 hours' then
    return query select false, false, 'provider_active';
    return;
  end if;

  -- الاقتراح مرتبط بطلب لم يُجب عنه بعد.
  if v_status <> 'pending' then
    return query select true, false, 'order_not_pending';
    return;
  end if;

  -- رسالة حجز/ناجحة قائمة لهذا الطلب → لا اقتراح ثانٍ.
  if exists (
    select 1
      from public.provider_alert_sms_log l
     where l.order_id = p_order_id
       and l.result in ('sending', 'sent')
  ) then
    return query select true, false, 'already_alerted';
    return;
  end if;

  -- حصة شهرية: رسالة ناجحة واحدة للمزوّد في شهر القاهرة.
  select count(*)::integer into v_monthly_used
    from public.provider_alert_sms_log l
   where l.provider_id = v_provider_id
     and l.result = 'sent'
     and l.sent_at >= (date_trunc('month', now() at time zone 'Africa/Cairo')) at time zone 'Africa/Cairo';

  if v_monthly_used >= 1 then
    return query select true, false, 'monthly_quota_used';
    return;
  end if;

  -- سقف يومي مجمّع (محاولات فعلية: sent + failed) في يوم القاهرة.
  select c.value into v_daily_cap
    from public.sms_cap_config c
   where c.key = 'provider_alert_global_per_day';
  v_daily_cap := coalesce(v_daily_cap, 50);

  select count(*)::integer into v_daily_used
    from public.provider_alert_sms_log l
   where l.result in ('sent', 'failed')
     and l.sent_at >= (date_trunc('day', now() at time zone 'Africa/Cairo')) at time zone 'Africa/Cairo';

  if v_daily_used >= v_daily_cap then
    return query select true, false, 'daily_cap_reached';
    return;
  end if;

  return query select true, true, 'ok';
end;
$$;

-- 9) الصلاحيات: الدوال الأربع للمستخدمين المسجّلين فقط
----------------------------------------------------------------------
revoke all on function public.provider_logout_preview() from public, anon;
revoke all on function public.provider_mark_logged_out() from public, anon;
revoke all on function public.provider_mark_active() from public, anon;
revoke all on function public.order_provider_alert_status(uuid) from public, anon;

grant execute on function public.provider_logout_preview() to authenticated;
grant execute on function public.provider_mark_logged_out() to authenticated;
grant execute on function public.provider_mark_active() to authenticated;
grant execute on function public.order_provider_alert_status(uuid) to authenticated;
