-- =============================================================================
-- admin_ban_user / admin_unban_user — v2
--
-- v1 (20261017034000): banned_until على auth.users + سجل الأدمن.
-- v2 (هذا الملف): يميّز الحظر الفعّال فورًا ويُعلم المستخدم:
--
--   1. عند الحظر: يسحب كل جلسات/توكنات المستخدم في SameMoment:
--        revoke على auth.refresh_tokens (يمنع أي تجديد جديد للتوكن).
--        حذف صفوف auth.sessions الخاصة بالمستخدم (جلسات GoTrue الحية).
--      الجلسة الحالية في الجهاز تُرفض عند محاولة أول refresh فورًا.
--
--   2. عند الحظر وبعد الرفع: يُدرج صف Notification نوع 'broadcast' مع
--      metadata {title, body} — نفس مسار الرسائل الجماعية الموجودة، فالتطبيق
--      يعترضه للعرض ويصل push عبر notify_push → edge → FCM — وبالتالي
--      المستخدم يعرف بالحدث فورًا (إشعار Push) وسيجده في تسجيل الإشعارات
--      عند العودة.
--
--   3. الإشعار لا يُدرج إلا لو للمستخدم صف في profiles (الfront-end
--      مقيّده بالفعل بمستخدمي profiles، والguard هنا احتياط).
--
-- كل التوقيعات/الأنواع unchanged من v1 → CREATE OR REPLACE يكفي.
-- Gated بـ assert_admin، جميع السياسات والصلاحيات كما في v1.
-- =============================================================================

create or replace function public.admin_ban_user(p_user_id uuid, p_reason text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text   := nullif(btrim(coalesce(p_reason, '')), '');
  v_tokens int    := 0;
  v_sessions int  := 0;
  v_notified boolean := false;
begin
  perform public.assert_admin();

  if v_reason is null or char_length(v_reason) < 5 then
    raise exception 'REASON_REQUIRED';
  end if;
  if exists (select 1 from public.admins where user_id = p_user_id) then
    raise exception 'CANNOT_BAN_ADMIN';
  end if;
  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception 'USER_NOT_FOUND';
  end if;

  if exists (
    select 1 from auth.users u
    where u.id = p_user_id
      and u.banned_until is not null
      and u.banned_until > now()
  ) then
    raise exception 'ALREADY_BANNED';
  end if;

  update auth.users u
  set banned_until = now() + interval '100 years'
  where u.id = p_user_id;

  -- سحب كل الجلسات: منع أي تجديد توكن + إنهاء جلسات GoTrue الحية.
  -- ملاحظة: refresh_tokens.user_id هنا character varying (سينما GoTrue القديمة)
  -- بياناً عن auth.users uuid — مقارنة مباشرة بـ uuid param ترمي 42883،
  -- لذا نحول للجانبين نصًا للمقارنة.
  update auth.refresh_tokens
  set revoked = true
  where user_id::uuid = p_user_id;
  get diagnostics v_tokens = row_count;

  delete from auth.sessions
  where user_id = p_user_id;
  get diagnostics v_sessions = row_count;

  -- إشعار المستخدم بالحدث (نفس مسار الرسائل الجماعية — بندعم push والعرض).
  if exists (select 1 from public.profiles where id = p_user_id) then
    insert into public.notifications (user_id, type, metadata)
    values (
      p_user_id,
      'broadcast',
      jsonb_build_object(
        'title', 'تم حظرك من استخدام تطبيق محور',
        'body', 'سبب الحظر: ' || v_reason || '. إذا كنت تعتقد أن هذا خطأ، تواصل مع الدعم.'
      )
    );
    v_notified := true;
  end if;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (
    auth.uid(),
    'ban_user',
    p_user_id,
    jsonb_build_object(
      'reason',          v_reason,
      'sessions_revoked', true,
      'refresh_revoked',  v_tokens,
      'sessions_deleted', v_sessions,
      'notified',         v_notified
    )
  );

  return (select banned_until from auth.users where id = p_user_id);
end;
$$;

revoke all on function public.admin_ban_user(uuid, text) from public;
revoke all on function public.admin_ban_user(uuid, text) from anon;
grant execute on function public.admin_ban_user(uuid, text) to authenticated, service_role;

create or replace function public.admin_unban_user(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_admin();

  update auth.users u
  set banned_until = null
  where u.id = p_user_id
    and u.banned_until is not null;

  if not found then
    raise exception 'NOT_BANNED';
  end if;

  -- إشعار المستخدم برفع الحظر.
  if exists (select 1 from public.profiles where id = p_user_id) then
    insert into public.notifications (user_id, type, metadata)
    values (
      p_user_id,
      'broadcast',
      jsonb_build_object(
        'title', 'تم رفع الحظر عن حسابك',
        'body', 'أصبح بإمكانك تسجيل الدخول إلى تطبيق محور من جديد.'
      )
    );
  end if;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (auth.uid(), 'unban_user', p_user_id, jsonb_build_object());

  return true;
end;
$$;

revoke all on function public.admin_unban_user(uuid) from public;
revoke all on function public.admin_unban_user(uuid) from anon;
grant execute on function public.admin_unban_user(uuid) to authenticated, service_role;
