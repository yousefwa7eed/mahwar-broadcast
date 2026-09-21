# تقرير تشخيصي — تطبيق «محور» (Mahwar)

**النطاق:** مراجعة أمنية/معمارية (مراجعة كود فقط — بدون تعديلات).
**التغطية:** تدفق العمليات (مالك ↔ مزوّد)، نظام الإشعارات، ملاحة الصفحات (فتح/إغلاق/رجوع)، معالجة الأخطاء، وأخطاء تفصيلية على مستوى الكود.
**الأدلة:** كود Flutter + جداول قاعدة بيانات عبر ويب سحابية (edge functions) + مهاجرات (مigrations) في `supabase/migrations` + مراجع `file:line`.

---

## 1) تدفق العمليات بين العميل والمزوّد (Order Flow)

سلسلة الحالة الهدف:

```
pending → priced → confirmed → completed
                  ↘ rejectedByProvider
                  ↘ rejectedByOwner
                  → cancelled (يدويًا/تلقائيًا)
```

### أ- إنشاء الطلب (Client)
- شاشة `service_request_screen.dart` تُدرج الطلب **مباشرةً من كود العميل** في جدول `orders` (status = `pending`).
- **المشكلة:** لا توجد أي migration هنا تنشئ جدول `orders` أو تُعرّف سياسات RLS للـ INSERT/UPDATE عليه (البحث لم يجد `create policy ... on public.orders` إلا في Increasing المهاجرة الخاصة بالـ trigger). الجدول الأساسي أُنشئ في «قاعدة مباشرة» (dashboard) **غير مُصدَّرة** في المستودع → فجوة إصدارة (schema drift). عند تفعيل `FORCE RLS` (مهاجرة `20260902150000_force_rls_and_with_check.sql`) أي عملية INSERT من العميل تعتمد على سياسة موجودة في القاعدة المباشرة غير موثّقة. **يجب التحقق من القاعدة المباشرة: هل توجد INSERT policy على `orders`؟**

### ب- الإسناد وكشف السعر
- «المزوّد» يرحّل الطلبات المعلقة المخصصّة له (حسب `provider_id`) ويطلب كشف سعر عبر `provider_set_price` (توقيع 5 وسائط: order_id, price, notes, eta, attachments).
- المهاجرة `20260902120000_harden_order_state_transitions.sql` أسقطت الإصدار القديم ثنائي الوسائط وحصّنت الانتقال ليكون `pending → priced` فقط.
- الإسناد يتم عبر `assign_order_to_provider` في `order_full_flow_v3.sql`.

### ج- التأكيد / الرفض
- المالك يؤكد (يُحدّث الحالة إلى `confirmed`) أو يرفض العرض (`rejectedByOwner`) عبر RPC من `request_tracking_screen.dart`.
- المزوّد يرفض عبر `rejectedByProvider`.

### د- الإكمال والتقييم
- المزوّد يكمل الطلب (`provider_complete_order` → `completed`) مع `provider_notes` / `eta_minutes`.
- المالك يقيّم في جدول `ratings` عبر سياسة «Owners rate orders».

---

## 2) النتائج الحرجة (أولويات عالية)

### 🔴 P0 — حقول الإلغاء التلقائي لا يُعيّن أبدًا → النظام «ميت»
- **الدليل:** كلمة `respond_deadline` تظهر في المستودع في 3 مواضع فقط: قراءة في `lib/core/models/order.dart:85`، فلترة في `supabase/functions/expire-pending-orders/index.ts:57-58`، واختبار في `test/widget_test.dart`. **لا يوجد أي كود يكتبها** — لا في `assign_order_to_provider`، ولا في insert الطلب، ولا أي `default` في جدول `orders`.
- **النتيجة:** فلتر cron المزوّد بـ `.not("respond_deadline", "is", null).lt(...)` لا يطابق أي صف ⇒ **الطلبات المعلقة لن تُلغى تلقائيًا أبدًا**. تعليق الدالة يدّعي «3 دقائق من لحظة الإسناد» لكن الكود لا يثبّت ذلك.
- **التكملة السلبية:** لا يوجد أي RPC لإلغاء الطلب من طرف المالك، ولا زر إلغاء في الواجهة ⇒ عندما يبقى الطلب `pending` بدون مزوّد يبقى معلقًا **للأبد**.
- **الإصلاح المتوقع:** تثبيت `respond_deadline` في `assign_order_to_provider` (مثلًا `now() + interval '3 minutes'`)، أو كـ fallback في الـ cron على `created_at + interval` عند كونها null؛ وإضافة مسار إلغاء للمالك.

### 🟠 P1 — واجهة المالك «لا تسجّل الخروج فعليًا»
- **الدليل:** `owner_home_screen.dart` زر الخروج ينفذ `context.go('/select-user-type')` **بدون** `signOut()`، بينما `provider_home_screen.dart` يستدعي `AuthService().signOut()`.
- **النتيجة:** المالك «يخرج» لكن الجلسة تبقى مفعّلة؛ وعند الدخول يُعاد توجيهه تلقائيًا لشاشة المالك، وقد يمنع تبديل الحساب.

### 🟠 P1 — env variable خاطئة في `delete-account`
- **الدليل:** `supabase/functions/delete-account/index.ts` يقرأ `SERVICE_ROLE_KEY` بينما بقية الدوال (send-push-notification، send-broadcast-notification…) تقرأ `SUPABASE_SERVICE_ROLE_KEY`.
- **النتيجة:** على hosted على الأرجح `SERVICE_ROLE_KEY` غير معرّف ⇒ استدعاء `cleanup_user_data` يفشل (البحث: RPC موجود في `20260819000001_cleanup_user_data.sql` بصلاحيات service_role فقط).

### 🟠 P1 — إعادة إنشاء الطلب مكررًا بعد الرجوع
- **الدليل:** بعد نجاح إرسال الطلب، `service_request_screen.dart` ينفذ `context.push('/request/providers')` **مُبقِيًا** شاشة الإنشاء في الـ stack. عند الرجوع من صفحة «المزوّدين القريبين» تُعرض شاشة إنشاء ببيانات قديمة، والضغط على إرسال مجددًا يُنشئ **طلبًا جديدًا مكررًا**. (علامة `_isSubmitting` تحمي فقط أثناء النداء).

### 🟠 P1 — عدم وجود سياسات RLS مُصدَّرة على `orders`
- كما في (أ) أعلاه؛ يُنصح بمزامنة القاعدة المباشرة مع مستودع migrations بعد “reconstructed” وتحويلها إلى مهاجرة كاملة منقّحة.

---

## 3) نظام الإشعارات

### التوجيه (deep-link) غير حساس للدور
- **الدليل:** كل الضغطات تُفتح `/request/track?orderId=` بغض النظر عمّن ضغط (مالك أو مزوّد).
- `request_tracking_screen.dart` لا يتحقق من دور المستخدم؛ في حالة `priced` تُعرض أزرار «قبول/رفض» الخاصة بالمالك — والمزوّد الذي يضغطها سيتلقّى رفض RPC `NOT_PRICED_OR_NOT_OWNOR` (رسالة إنجليزية). والزر «رجوع» يعيد دائمًا إلى `/home/owner`.

### الإعداد على مستوى الجلسة بدون fallback فعلي
- **الدليل:** مهاجرة `20260903120000_add_notify_push_trigger.sql` تقرأ فقط `current_setting('app.settings.edge_url')` ثم `app.settings.project_ref` (يُعمّر `https://{ref}.supabase.co/functions/v1/...`) و`app.settings.order_event_secret`. التعليق يدّعي fallback إلى متغيرات بيئة، لكن الكود لا يحتويه.
- **النتيجة:** إن لم تُثبَّت هذه الإعدادات على الجلسة/الدور، يرفع `raise notice` فقط وتختفي إشعارات الدفع صامتة.
- **ملاحظة جيدة:** مسار التنظيف الحُرْفي (`order_terminal_cleanup`) يستخدم جدول singleton `order_event_secret` (نظيف من مشكلة الإعدادات) لكنه يتطلب زرع السر يدويًا خارج المهاجرة.

### شارة «غير المقروءة»
- تُحسب فقط على آخر ~50 إشعارًا مُحمَّلًا ⇒ احتمال عدد ناقص عند كثرة الإشعارات.

### تكديس مكرر للـ Home في الـ stack
- عند معالجة deep-link `'home'` في `notifications_screen` يستخدم push نحو `/home/owner` بدل استبدالها ⇒ نسخة ثانية من الصفحة الرئيسية تُكدّس والرجوع يُعيد للإشعارات.

---

## 4) ملاحة الصفحات (فتح / إغلاق / رجوع)

| المشكلة | التأثير | الملف |
|---|---|---|
| Back fallback في `request_tracking` دائمًا `/home/owner` | مزوّد يضغط إشعار فيُعاد لشاشة مالك | `request_tracking_screen.dart` |
| الضغط على إشعارات الطلب → صفحة tracking حساسة للدور | مزوّد يرى أزرار مالك | push_notification_service + request_tracking |
| `context.push('/request/providers')` بدون مسح حالة الإنشاء | إعادة الإرسال = طلب مكرر | service_request_screen |
| `context.push` لـ home من الإشعارات | تكديس نسخة ثانية | notifications_screen |
| الخروج من حساب المالك | لا يسجّل خروجًا فعليًا | owner_home_screen |

---

## 5) معالجة الأخطاء

- معظم الشاشات تعرض رسالة الخطأ الواردة من RPC مباشرة للمستخدم (مثل `NOT_PRICED_OR_NOT_OWNER`، `ORDER_NOT_FOUND_OR_FORBIDDEN`) **بالإنگليزية** ودون ترجمة أو تبسيط.
- لا يوجد طبقة وسيطة (مثل محوّل أخطاء) تُترجم أكواد RPC إلى رسائل عربية صديقة.
- الاستثناءات الناتجة عن فشل الإشعارات أو الشبكة تُلتقط غالبًا وخفيًا (بدون تنبيه المستخدم).
- RPCs لا ترمي رسائل عربية — كل الاستثناءات المخصصة إنجليزية.

---

## 6) أخطاء تفصيلية (Detail-level)

1. **مزامنة الإسناد غير ذرّية:** `assign_order_to_provider` يقرأ بوجود check ثم يُحدّث دون `where provider_id is null` ضمن نفس UPDATE ⇒ في تتابع نادر قد يُعلق مزوّدان لنفس الطلب ويكون كلاهما قد أُخطَر.
2. **مرفقات يتيمة (orphaned storage):** في `provider_offer_price` تُرفع صور المزوّد إلى storage قبل استدعاء RPC؛ عند فشل التفاوض (ORDER_NOT_PENDING/SET PRICE) لا يوجد تنظيف للمرفقات المرتفعة.
3. **أسماء الخدمة الهَشّة:** `kServiceCategories` يستخدم ids عرض UI (`tires`, `mechanic`...) بينما قاعدة البيانات تستخدم أخرى (`tire`, `mechanical`...)، مع خريطة `_serviceTypeIdMap` في service_request تحوّل فقط بعضها؛ أي id خارجها يمر كما هو ويكسر FK — وكانت هذه النقطة نفسها سبب تعليق العمل سابقًا (تعليق in code).
4. **anon key مضمّن:** `lib/main.dart:21-24` يثبّت URL القاعدة ومفتاح anon صراحةً — طبيعي لمشاريع Supabase مرجعية، لكن يُوصى بنقله إلى متغيرات بيئة (`.env`) خاصةً مع تاريخ انتهاء المفتاح.
5. **العارض الممتد:** لا يوجد استماع realtime لـ orders لدى شاشة المالك (يُحمّل فقط عند الفتح/المزامنة اليدوية)، بينما provider_home يستمع عبر القناة على `provider_id` ⇒ المالك قد يضل بدون تحديث فوري لحالة طلبه.
6. **cron الصيانة:** `expire-pending-orders` يمسح `respond_deadline` بعد الإلغاء، لكنه بدونه لا يعمل إطلاقًا (P0).

---

## 7) ملخص حسب الأولوية

| الأولوية | المشكلة | الإصلاح المتوقع |
|--|--|--|
| P0 | `respond_deadline` لا يُعيّن ⇒ إلغاء تلقائي معطّل، طلبات معلقة للأبد بلا إلغاء | تثبيتها في assign / fallback في cron + إضافة مسار إلغاء للمالك |
| P1 | خروج المالك بلا signOut | استدعاء `AuthService().signOut()` قبل navigation |
| P1 | `delete-account` يستخدم env خاطئة | توحيد `SUPABASE_SERVICE_ROLE_KEY` |
| P1 | إعادة الإنشاء المكرر بعد الرجوع من المزوّدين القريبين | استبدال push بـ go (مسح الستاك) + تعطيل الإرسال بعد النجاح |
| P1 | Deep-link إشعارات غير حساسة للدور + back→home/owner | تمرير الدور في التنقل واختيار الوجهة حسب الدور |
| P1 | سياسات RLS على `orders` غير مُصدَّرة | مزامنة قاعدة مباشرة → migration + تدقيق INSERT/UPDATE policy |
| P2 | notify_push بلا fallback فعلي للبيئة | إضافة env fallback أو استخدام table singleton |
| P2 | أخطاء RPC إنجليزية للمستخدم | طبقة ترجمة/تبسيط للأخطاء |
| P2 | Race في assign + مرفقات يتيمة | update ذرّي بـ where + cleanup عند الفشل |
| P3 | شارة غير مقروءة (حد التحميل)، تكديس نسخة home، أسماء خدمة هشّه، anon key | تحسينات تجميلية/هيكلية |

---

## مصادر التحقق الرئيسية
- `supabase/migrations/20260828063145_order_full_flow_v3.sql` — RPCs (assign، get_nearest_providers مع فلتر is_online)
- `supabase/functions/expire-pending-orders/index.ts` — cron (لا يطابق شيئًا بدون respond_deadline)
- `supabase/migrations/20260903120000_add_notify_push_trigger.sql` — إعدادات الجلسة بدون fallback
- `supabase/functions/delete-account/index.ts` + `20260819000001_cleanup_user_data.sql`
- `lib/features/owner_home/owner_home_screen.dart` — خروج بلا signOut
- `lib/features/request_tracking/request_tracking_screen.dart` — back fallback وواجهة المالك
- `lib/features/service_request/service_request_screen.dart` — insert مباشر + خريطة الخدمة + push
- `lib/features/owner_home/widgets/services_grid.dart` — ids عرض UI