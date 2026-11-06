-- Migration: Tighten public_provider_profiles ACL to SELECT-only.
-- (applied to live as 20261106150713; ACL + latest version verified back from
--  pg_class.relacl / supabase_migrations.schema_migrations after apply.)
--
-- السبب (threat model):
--   public_provider_profiles منظر (view) يملكه postgres ويُقرأ كـ definer (صلاحيات
--   المالك)، وهو المسار الثاني للوصول لبيانات المزوّدين بخلاف الـ RPC (وثّقه تقرير
--   التدقيق كـ C2/L-5/م-5 مع قرار المنتج M-C).
--   migration ‏20260918060000 قصَدت تثبيت «SELECT لـ authenticated فقط» عبر REVOKE ALL
--   ثم GRANT SELECT، لكن بقايا GRANT ALL ON ALL TABLES IN SCHEMA public التاريخية
--   أعادت منح INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER/MAINTAIN لـ
--   authenticated و service_role — قرأنا relacl الحي في 2026-11-06 وأكّد ذلك
--   (ولهذا رفع get_advisors تحذير security_definer_view كخطأ ERROR).
--   الكتابة عبر المنظر كانت محكومة بأمن الجداول السفلية (postgres غير مالك لـ
--   providers/profiles؛ كلاهما لديه RLS + owners) فالخطر الحالي نظري، لكن تضييق
--   سطح الهجوم إلى ما صُمّم من أجله المنظر (قراءة فقط) هو الوضع السليم.
--
-- لا كسر لأي مسار:
--   كل الاستخدامات في lib/ و supabase/ هي SELECT فقط؛ دوال
--   get_nearest_providers / get_provider_details / create_order_for_provider
--   SECURITY DEFINER يملكها postgres وتصل للجداول مباشرة، ولا كائنات تابعة للمنظر
--   (pg_depend deptype='r' = 0 حيًّا). دخان ما بعد التطبيق: قراءة المنظر أعادت
--   الصفوف والأعمدة كاملة.
--
-- ملاحظة: يظل security_definer_view يظهر في مستشار الأمان لهذا المنظر؛ مقبول وموثّق —
--   التحذير عن طبيعة المنظر كـ definer لا عن الـ ACL، والتعرض قبل الطلب قرار منتج (M-C).

revoke all on public.public_provider_profiles from public;
revoke all on public.public_provider_profiles from anon;
revoke all on public.public_provider_profiles from authenticated;
revoke all on public.public_provider_profiles from service_role;
grant select on public.public_provider_profiles to authenticated;
grant select on public.public_provider_profiles to service_role;
