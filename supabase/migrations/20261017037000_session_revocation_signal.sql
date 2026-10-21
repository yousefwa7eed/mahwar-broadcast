-- =============================================================================
-- session_revocation_signal
--
-- يكمل admin_ban_session_and_notify: الإشعار ورفض التوكنات ليست كافيين
-- لخروج فوري من التطبيق لأن الـ JWT الحالي يبقى ساريًا حتى تمدده.
--
-- آلية الخروج الفوري (Realtime kill switch):
--   1. عمود جديد public.profiles.session_revoked_at.
--   2. admin_ban_user يضبطه = now() ويضيف صف's realtime لجدول profiles.
--   3. التطبيق (auth_cubit) يشترك بقناة Realtime على صفه في profiles — عند
--      وصول تحديث فيه session_revoked_at != null يسجل خروجًا فورًا.
--   4. admin_unban_user يصفّر العمود.
-- الفلتر متسقة مع سياسة RLS Profiles: (auth.uid() = id) — الحدث يصل واحذ
-- للمستخدم المتأثر وتحتاج إلى الجلسة JWT Still Valid.
-- =============================================================================

alter table public.profiles add column if not exists session_revoked_at timestamptz;

alter publication supabase_realtime add table public.profiles;
