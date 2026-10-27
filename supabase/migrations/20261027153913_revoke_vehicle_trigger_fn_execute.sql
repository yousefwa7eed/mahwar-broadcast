-- دوال trigger الخاصة بجدول vehicles لا يحتاجها أي دور عبر PostgREST: المشغّل ينفّذها
-- بصلاحية مالكها. كلتاهما SECURITY DEFINER، فبقاء منح EXECUTE الافتراضي (PUBLIC) كان
-- يتيح لـ anon/authenticated استدعاءهما مباشرة كـ RPC — رصده security advisor بعد ترحيل
-- vehicles. نزيل المنح عن الجميع، ويبقى التنفيذ عبر المشغّل فقط.
revoke all on function public.vehicles_before_write() from public, anon, authenticated;
revoke all on function public.vehicles_after_delete() from public, anon, authenticated;
