-- Migration: Lock down trigger-only SECURITY DEFINER functions from REST.
-- (applied to live as 20261106151328; exec_grantees + trigger + signup path
--  verified back live after apply — smoke insert into auth.users fired
--  handle_new_user through supabase_auth_admin and rolled back cleanly with
--  MISSING_VEHICLE, and on_notification_created remains enabled.)
--
-- السياق (threat model):
--   الدوال الخمس تُنفَّذ حصراً من داخل triggers/event trigger، وهي SECURITY DEFINER
--   بمالك postgres فتتجاوز صلاحيات/RLS المستدعي. كان EXECUTE ممنوحًا لـ
--   authenticated (بقايا GRANT EXECUTE التاريخي؛ قرئ حيًّا من pg_proc.proacl في
--   2026-11-06) أي أنها نقاط REST زائدة بلا أي مستدعٍ:
--     - handle_new_user()          ← trigger on auth.users insert (signup guard)
--     - handle_user_email_update() ← trigger on auth.users email update
--     - guard_role_immutable()     ← BEFORE UPDATE trigger على profiles (قفل الدور)
--     - notify_push()              ← AFTER INSERT trigger على notifications
--     - rls_auto_enable()          ← event trigger على CREATE TABLE
--   لا نداء في lib/ ولا admin-dashboard ولا supabase/functions عبر REST لأيٍّ منها
--   (بحث نصي 2026-11-06). التريغرات لا تتأثر: تُنفَّذ بصلاحية مالك الجدول
--   (postgres) فتتجاوز فحص EXECUTE.
--
-- ما أُبقي عمداً:
--   - supabase_auth_admin على handle_new_user / handle_user_email_update
--     (خدمة Auth تنفّذهما؛ بدونه يتعطّل التسجيل وتحديث البريد).
--   - service_role كاحتياطي break-glass (مفتاح داخلي، ليس في أي حزمة عميل).
--
-- الأثر الأمني: إلغاء nِقاط REST غير مقصودة — أهمها إمكانية إعادة تشغيل
--   منطق التسجيل بمحتوى raw_user_meta_data من جلسة المستخدم، ومسارات جانبية
--   (notify_push/rls_auto_enable/guard_role_immutable) من واجهة API.
-- ملاحظة: هذه الدوال تظل ضمن تحذير advisor العام
--   authenticated_security_definer_function_executable (موثّق في تقرير التدقيق
--   B6/الأجزاء B1–B4: الDEFINER + search_path='' + حروب is_admin()/auth.uid()
--   هو المعمارية المقصودة لكل دوال الأعمال).

revoke execute on function public.handle_new_user()          from public, anon, authenticated;
revoke execute on function public.handle_user_email_update() from public, anon, authenticated;
revoke execute on function public.guard_role_immutable()     from public, anon, authenticated;
revoke execute on function public.notify_push()              from public, anon, authenticated;
revoke execute on function public.rls_auto_enable()          from public, anon, authenticated;
