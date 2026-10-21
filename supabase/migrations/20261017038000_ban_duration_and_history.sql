-- =============================================================================
-- ban_duration_and_history
--
-- 1) admin_ban_user يضيف مدة يومية اختيارية (p_ban_days int default null):
--    - null → دائم (كما كان: 100 سنة).
--    - >=1 (سقف 730) → now() + make_interval(days => p_ban_days).
--    الحظر المؤقت يبتدئ فورًا وينتهي تلقائيًا: Gotrue يرفض الدخول ما دام
--    banned_until > now()، وبعد انتهاؤه يقبل الدخول دون تدخل الأدمن.
--    الإشعار للمستخدم يذكر المدة وتاريخ الانتهاء، وسجل الأدمن يسجل العمر.
--    نفس آليات v2: سحب refresh_tokens + حذف sessions + session_revoked_at
--    (realtime kill switch) + إشعار push.
--    يتغير التوقيع (uuid,text) → (uuid,text,int) فلا بد DROP ثم إنشاء.
--
-- 2) admin_ban_history — RPC لسجل عمليات الحظر/الرفع من admin_audit_log.
--    يرسم اسم/إيميل المستهدف من profiles/auth.users، ويرفع حالة "محظور حاليًا".
-- =============================================================================

drop function if exists public.admin_ban_user(uuid, text);

create or replace function public.admin_ban_user(
  p_user_id uuid,
  p_reason text,
  p_ban_days int default null
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text       := nullif(btrim(coalesce(p_reason, '')), '');
  v_ban_days int      := nullif(p_ban_days, 0);
  v_banned_until timestamptz;
  v_tokens int        := 0;
  v_sessions int      := 0;
  v_notified boolean  := false;
  v_temporary boolean := false;
begin
  perform public.assert_admin();

  if v_reason is null or char_length(v_reason) < 5 then
    raise exception 'REASON_REQUIRED';
  end if;
  if v_ban_days is not null and v_ban_days < 1 then
    raise exception 'INVALID_DURATION';
  end if;
  if v_ban_days is not null and v_ban_days > 730 then
    raise exception 'INVALID_DURATION';
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

  v_temporary := v_ban_days is not null;
  v_banned_until := case
    when v_temporary then now() + make_interval(days => v_ban_days)
    else now() + interval '100 years'
  end;

  update auth.users u
  set banned_until = v_banned_until
  where u.id = p_user_id;

  -- سحب كل الجلسات: منع أي تجديد توكن + إنهاء جلسات GoTrue الحية.
  -- ملاحظة: refresh_tokens.user_id هنا character varying (سينما GoTrue
  -- القديمة) بياناً عن uuid — لذا نحول للجانبين نصًا للمقارنة.
  update auth.refresh_tokens
  set revoked = true
  where user_id::uuid = p_user_id;
  get diagnostics v_tokens = row_count;

  delete from auth.sessions
  where user_id = p_user_id;
  get diagnostics v_sessions = row_count;

  -- إشارة الخروج الفوري عبر Realtime على صف المستخدم.
  update public.profiles
  set session_revoked_at = now()
  where id = p_user_id;

  if exists (select 1 from public.profiles where id = p_user_id) then
    insert into public.notifications (user_id, type, metadata)
    values (
      p_user_id,
      'broadcast',
      jsonb_build_object(
        'title', 'تم حظرك من استخدام تطبيق محور',
        'body',
          case
            when v_temporary then
              'سبب الحظر: ' || v_reason ||
              '. حظر مؤقت لمدة ' || v_ban_days || ' يوم (ينتهي: ' ||
              to_char(v_banned_until, 'YYYY-MM-DD') ||
              '). إذا كنت تعتقد أن هذا خطأ، تواصل مع الدعم.'
            else
              'سبب الحظر: ' || v_reason ||
              '. إذا كنت تعتقد أن هذا خطأ، تواصل مع الدعم.'
          end
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
      'reason',           v_reason,
      'ban_days',         v_ban_days,
      'temporary',        v_temporary,
      'banned_until',     v_banned_until,
      'sessions_revoked', true,
      'refresh_revoked',  v_tokens,
      'sessions_deleted', v_sessions,
      'notified',         v_notified
    )
  );

  return (select banned_until from auth.users where id = p_user_id);
end;
$$;

revoke all on function public.admin_ban_user(uuid, text, int) from public;
revoke all on function public.admin_ban_user(uuid, text, int) from anon;
grant execute on function public.admin_ban_user(uuid, text, int) to authenticated, service_role;

-- =============================================================================

create or replace function public.admin_ban_history(
  p_page      int  default 1,
  p_page_size int  default 25
)
returns table (
  action           text,
  created_at       timestamptz,
  target_id        uuid,
  target_name      text,
  target_email     text,
  reason           text,
  ban_days         int,
  banned_until     timestamptz,
  currently_banned boolean,
  total_count      bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 25), 1), 100);
begin
  perform public.assert_admin();

  return query
  with base as (
    select
      a.action                                                        as act,
      a.created_at,
      a.target_user_id                                                as tid,
      a.details->>'reason'                                            as r,
      nullif(a.details->>'ban_days', '')::int                         as bd,
      nullif(a.details->>'banned_until', '')::timestamptz             as bu,
      coalesce(tp.full_name, ta.email)                                as t_name,
      ta.email                                                        as t_email,
      exists (
        select 1 from auth.users du
        where du.id = a.target_user_id
          and du.banned_until is not null
          and du.banned_until > now()
      )                                                               as cb,
      count(*) over ()                                                as total
    from (
      select x.*, row_number() over (order by x.created_at desc) as rn
      from public.admin_audit_log x
      where x.action in ('ban_user', 'unban_user')
    ) x
    left join public.profiles tp on tp.id = x.target_user_id
    left join auth.users    ta   on ta.id = x.target_user_id
  )
  select
    b.act, b.created_at, b.tid, b.t_name, b.t_email,
    b.r, b.bd, b.bu, b.cb, b.total
  from base b
  order by b.created_at desc
  limit v_size offset (v_page - 1) * v_size;
end;
$$;

revoke all on function public.admin_ban_history(int, int) from public;
revoke all on function public.admin_ban_history(int, int) from anon;
grant execute on function public.admin_ban_history(int, int) to authenticated, service_role;
