# تقرير التقييم الأمني — Mahwar (OWASP Top 10 2021)

- **التاريخ:** 2026-09-23
- **المشروع:** `trgesfzojaoirutkkfcs` («mahwar»)، المنطقة eu-central-1، Postgres 17
- **النطاق:** تطبيق Flutter + Supabase (RLS/RPCs + 6 دوال edge + Storage + إعدادات Auth)
- **المرجع:** التقرير السابق `docs/security_audit_report.md` (ثغراته وُثِّقت وحُلّت مباشرةً)

---

## الخلاصة التنفيذية

البنية الخلفية (Supabase) **محصّنة بشدة** بعد التدقيقات السابقة: لا منح `anon` متبقية على دوال دورة الطلب،
وكل RPCs تحمل حارس الملكية `IS DISTINCT FROM` ضد NULL-bypass مع تثبيت `search_path`، وحماية
`guard_role_immutable` للدور، وتقييدات إدراج صارمة على `orders`/`ratings`/`providers`. لا توجد ثغرات
**High أو Critical** متبقية ومؤكَّدة.

ما تبقى تحقيقًا لهذا التدقيق: **4 ملاحظات Medium** (قرارات منتج مؤجلة + إعدادات Auth/التخزين المحلي
للجلسة) و**5 ملاحظات Low** وأخرى Info/ممارسات نظيفة.

---

## نقاط القوة التي تم التحقق منها (سليمة)

- جميع RPCs دورة الطلب: `anon_exec=false`، مع `auth.uid() IS NULL OR … IS DISTINCT FROM auth.uid()`،
  و`set search_path = ''` وتأهيل كامل للأسماء (`public.*`).
- سياسة `orders` الإدراجية: `status='pending'`، `provider_id IS NULL`، `offered_price IS NULL` —
  لا يمكن إنشاء طلب مشوّه؛ التسعير/الإسناد/القبول/الرفض حصرًا عبر RPCs محمية.
- `update_auth_email` يرفض تعديل بريد غير صاحب الحساب؛ `ratings` إدراج مباشر محذوف (RPC-only).
- `providers` INSERT يتطلب `profiles.role='provider'`؛ أُسقطت سياسة `ALL` الواسعة.
- `get_public_profile` مقيدة بمشاركة فعلية في طلب بين الطرفين؛ `get_email_by_phone` محدود 5/ساعة/رقم.
- `delete-account` يتحقق من JWT عبر `supabase.auth.getUser()` ثم ينظف عبر service role، ويحذف
  المستخدم، مع إصلاح متغير `SUPABASE_SERVICE_ROLE_KEY` (commit `6a146ce`).
- iOS بلا استثناءات ATS (HTTPS مفروض)؛ Android `allowBackup="false"` + `fullBackupContent="false"`.
- فحص تاريخ git: لا توجد أسرار backend (service roles/keys) مكدسة في المستودع أو سجلّها.
- سياسات `orders` تحافظ على `updated_at` تلقائيًا؛ `notify_push` وغيرها من المشغّلات تعمل عبر service_role
  وبلا وصول API مباشر.

---

## فجوات قائمة (مصنفة حسب الخطورة)

### 🟠 Medium

| # | الوصف | الموقع | OWASP |
|---|---|---|---|
| M-A | **تخزين الجلسة نصًا عاديًا:** supabase_flutter يخزن access + refresh JWT افتراضيًا في SharedPreferences؛ لا يوجد `flutter_secure_storage` في `pubspec.yaml`. يُعرض للاقتناص عبر backup أو جهاز Rooted/مخترق. | `pubspec.yaml:41` (supabase_flutter) | A07 / OWASP Mobile M9 |
| M-B | **سياسة كلمات مرور ضعيفة:** `minimum_password_length = 6`، `password_requirements = ""`، `enable_confirmations = false` (بريد بلا تأكيد)، `secure_password_change = false`، و`auth_leaked_password_protection` معطّل (لوحة التحكم). | `supabase/config.toml:182-228` | A07 |
| M-C | **M1 (قرار منتج مؤجل):** أي مستخدم مصادق يرى هاتف/عنوان/إحداثيات أي مزوّد **قبل أي ربط بطلب** عبر `get_nearest_providers`/`get_provider_details`/`public_provider_profiles` (view من نوع definer). | `20260828063145_order_full_flow_v3.sql` | A01 |
| M-D | **M3 (قرار منتج مؤجل):** سياسة التخزين «Allow Authenticated Uploads» (أي مصادق يكتب لأي مسار) و bucket `order-attachments` للقراءة العامة (صور سيارات = بيانات شخصية). السياسات **غير موجودة في migrations** (مكوّنة في Dashboard فقط) → انجراف وحدة تحكم غير قابلة للمراجعة عبر المستودع. | Supabase Storage | A01 |

### 🟡 Low

| # | الوصف | الموقع | OWASP |
|---|---|---|---|
| L-1 | `get_email_by_phone` يبقى `anon` (قرار مقصود لإبقاء تسجيل الدخول)، لكن cap 5/ساعة/رقم قابل للتجاوز بتدوير الأرقام → تعداد حسابات + استهداف صيد. | `20260918140000_throttle_get_email_by_phone.sql` | A01 |
| L-2 | **سر مشترك واحد `ORDER_EVENT_SECRET`** يفتح كل الدوال الحساسة (broadcast/push/حذف مرفقات/إنهاء طلبات معلّقة). تسريبه = مالكات جماعية + DoS. يُنصح: سر منفصل لكل وظيفة + rotation + مقارنة متساوية الزمن. | `supabase/functions/**/index.ts` | A08 |
| L-3 | **لا تثبيت شهادات (certificate pinning)** ولا كشف Root/Jailbreak → MITM ممكن على أجهزة مخترقة. | Flutter / الشبكة | A07 (دفاع عمقي) |
| L-4 | **إصدار Deno قديم** (`deno.land/std@0.177.0`) في كل الدوال بلا تجزئة استيراد. | `supabase/functions/*/index.ts` | A06 |
| L-5 | أي مصادق يقرأ `public_provider_profiles` مباشرة (مسار ثانٍ لنفس بيانات M-C بخلاف الـ RPC). | عرض `public_provider_profiles` | A01 |

### 🔵 Info / ملاحظات

- **`lib/main.dart:20-28`**: anon key و URL كقيم افتراضية `String.fromEnvironment` — المفتاح publishable
  بأمانه، لكن يُنصح بإجبار `--dart-define` في بناءات release وعدم نشر قيم بديلة حية.
- **`android/app/google-services.json`** ملتزم (مقبول في تطبيقات الجوال؛ يُنصح تقييد Android API key
  بالحزمة + SHA-1).
- **غياب `INTERNET` في `AndroidManifest.xml` (main)** — ليس أمنًا بل وظيفيًا: الـ plugins تضيفه عند المزج؛
  يُتحقق في ملف release المبني.
- **`refresh_token_reuse_interval = 10`** ثوانٍ مسموح بإعادة استخدام توكن التحديث خلالها — يُنصح تخفيضه إلى 0.
- **لا حارس توجيه (router guard)** على مستوى Flutter — مقبول لأن رفض الوصول منسوخ في RLS/RPCs.
- **OTP/تسجيل دخول:** `shouldCreateUser:false` يمنع إنشاء حسابات عبر رقم غير مسجّل؛ حدود المعدل
  (`sign_in_sign_ups=30`، `token_verifications=30`، `sms_sent=30`) مفعّلة.
- **أنماط OTP:** `otp_length=6` / `otp_expiry=3600`، `max_frequency` محدد — ضمن الحدود المقبولة.

---

## توصيات ذات أولوية

1. **جلسة آمنة (M-A):** استخدام `flutter_secure_storage` (Keychain/Keystore) مع `Supabase.initialize`
   و localStorage مخصص بدل SharedPreferences؛ إضافة قفل Biometric/PIN اختياري على فتح التطبيق.
2. **تقوية Auth (M-B):** `minimum_password_length=8` على الأقل، تفعيل `password_requirements`
   (أحد: letters_digits مثلًا)، `enable_confirmations=true`، `secure_password_change=true`، وتفعيل
   `auth_leaked_password_protection` من لوحة التحكم.
3. **إصلاح سريع:** `refresh_token_reuse_interval=0`؛ تحديث Deno std إلى إصدار حديث مثبّت مع `--lock`.
4. **قرارات منتج (M-C / M-D):** كشف هاتف/عنوان المزوّد فقط لمشارك في طلب فعلي (أو ربطه بطلب)،
   وإعادة هيكلة مسارات Storage (`orders/<orderId>/...`) مع تحقق من الانتماء للطلب، ومراجعة سياسة
   القراءة العامة للـ bucket. هذه تحتاج قرار عمل لا إصلاح تقني فقط.
5. **متابعة دورية:** تحويل سياسات Storage إلى migrations (IaC) كي تكون قابلة للمراجعة والمطابقة.

---

## ترتيب اقتراحي للمعالجة

1. **M-A + M-B** (أثر أمني مباشر، بلا تعارض منتج) — المعالجة التقنية الآن.
2. **L-2 + L-4 + refresh reuse** — إصلاحات سريعة منخفضة التكلفة.
3. **M-C + M-D** — تُطرح كقرارات منتج (جدولة).
4. Dashboard: تفعيل leaked-password protection، ومراجعة معدلات Auth الحية (لا يمكن فحصها عبر SQL).