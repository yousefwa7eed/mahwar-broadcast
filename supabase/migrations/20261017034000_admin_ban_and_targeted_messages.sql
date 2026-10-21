-- =============================================================================
-- Yousef requests (2026-10-17):
--   a) ban / unban users from the dashboard, audited, with reason.
--   b) targeted messages (custom broadcast) to one user, a group he picks
--      (owners / providers), or individually selected users.
--   c) visibility of ban state in the users list.
-- Delivery relies on existing infra only:
--   * notifications rows with type='broadcast' are rendered by the app from
--     metadata {title, body, deep_link?} (notification_model.dart).
--   * a per-row DB trigger (notify_push) posts the notification to
--     send-push-notification edge -> FCM (profiles.fcm_token). So inserting
--     broadcast rows automatically pushes them.
-- Ban uses auth.users.banned_until (GoTrue blocks sign-in + token refresh).
-- =============================================================================

drop function if exists public.admin_list_users(int, int, text, text);
drop function if exists public.admin_export_users(text, text);

-- ---------------------------------------------------------------------------
-- admin_list_users v3: adds banned / banned_until (from auth.users).
-- Same guards and columns as the unmasked version otherwise.
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_users(
  p_page      int  default 1,
  p_page_size int  default 25,
  p_search    text default null,
  p_role      text default null
)
returns table (
  user_id            uuid,
  full_name          text,
  phone_number       text,
  email              text,
  role               text,
  workshop_name      text,
  is_online          boolean,
  phone_verified     boolean,
  national_id        text,
  banned             boolean,
  orders_as_owner    int,
  orders_as_provider int,
  created_at         timestamptz,
  total_count        bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_page   int := greatest(coalesce(p_page, 1), 1);
  v_size   int := least(greatest(coalesce(p_page_size, 25), 1), 100);
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_digits text;
  v_role   public.user_role;
begin
  perform public.assert_admin();

  if v_search is not null then
    v_digits := nullif(regexp_replace(v_search, '\D', '', 'g'), '');
  end if;

  v_role := case
    when coalesce(p_role, '') in ('car_owner', 'provider')
    then p_role::public.user_role
  end;

  return query
  with base as (
    select
      pr.id                                   as uid,
      pr.full_name,
      pr.phone_number,
      pr.email,
      pr.role::text                           as role_text,
      pw.workshop_name,
      pw.is_online,
      (pr.phone_verified_at is not null)      as phone_verified,
      pr.national_id,
      (au.banned_until is not null and au.banned_until > now()) as banned,
      pr.created_at,
      count(*) over ()                        as total
    from public.profiles pr
    left join public.providers pw on pw.id = pr.id
    left join auth.users au       on au.id  = pr.id
    where (v_role is null or pr.role = v_role)
      and (
        v_search is null
        or pr.full_name  ilike '%' || v_search || '%'
        or pr.email      ilike '%' || v_search || '%'
        or pw.workshop_name ilike '%' || v_search || '%'
        or (v_digits is not null
            and (regexp_replace(pr.phone_number, '\D', '', 'g') like '%' || v_digits || '%'
                 or (pr.national_id is not null
                     and translate(pr.national_id,
                           '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'::text,
                           '01234567890123456789'::text)
                          like '%' || v_digits || '%')))
      )
  )
  select
    b.uid,
    b.full_name,
    b.phone_number,
    b.email,
    b.role_text,
    b.workshop_name,
    b.is_online,
    b.phone_verified,
    b.national_id,
    b.banned,
    coalesce((select count(*) from public.orders o where o.car_owner_id = b.uid), 0)::int,
    coalesce((select count(*) from public.orders o where o.provider_id = b.uid), 0)::int,
    b.created_at,
    b.total
  from base b
  order by b.created_at desc, b.uid
  limit v_size
  offset (v_page - 1) * v_size;
end;
$$;

revoke all on function public.admin_list_users(int, int, text, text) from public;
revoke all on function public.admin_list_users(int, int, text, text) from anon;
grant execute on function public.admin_list_users(int, int, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- admin_export_users v2: adds user_id (needed by the messages composer to
-- resolve group recipients) and banned; CSV headers updated in the frontend.
-- ---------------------------------------------------------------------------
create or replace function public.admin_export_users(
  p_search text default null,
  p_role   text default null
)
returns table (
  user_id            uuid,
  full_name          text,
  phone_number       text,
  email              text,
  national_id        text,
  role               text,
  workshop_name      text,
  is_online          boolean,
  phone_verified     boolean,
  banned             boolean,
  orders_as_owner    int,
  orders_as_provider int,
  created_at         timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_digits text;
  v_role   public.user_role;
  v_marked bigint;
begin
  perform public.assert_admin();

  if v_search is not null then
    v_digits := nullif(regexp_replace(v_search, '\D', '', 'g'), '');
  end if;

  v_role := case
    when coalesce(p_role, '') in ('car_owner', 'provider')
    then p_role::public.user_role
  end;

  with base as (
    select
      pr.id                                   as uid,
      pr.full_name,
      pr.phone_number,
      pr.email,
      pr.national_id,
      pr.role::text                           as role_text,
      pw.workshop_name,
      pw.is_online,
      (pr.phone_verified_at is not null)      as phone_verified,
      (au.banned_until is not null and au.banned_until > now()) as banned,
      pr.created_at,
      count(*) over ()                        as total
    from public.profiles pr
    left join public.providers pw on pw.id = pr.id
    left join auth.users au       on au.id  = pr.id
    where (v_role is null or pr.role = v_role)
      and (
        v_search is null
        or pr.full_name  ilike '%' || v_search || '%'
        or pr.email      ilike '%' || v_search || '%'
        or pw.workshop_name ilike '%' || v_search || '%'
        or (v_digits is not null
            and (regexp_replace(pr.phone_number, '\D', '', 'g') like '%' || v_digits || '%'
                 or (pr.national_id is not null
                     and translate(pr.national_id,
                           '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'::text,
                           '01234567890123456789'::text)
                          like '%' || v_digits || '%')))
      )
  )
  select
    b.uid,
    b.full_name,
    b.phone_number,
    b.email,
    b.national_id,
    b.role_text,
    b.workshop_name,
    b.is_online,
    b.phone_verified,
    b.banned,
    coalesce((select count(*) from public.orders o where o.car_owner_id = b.uid), 0)::int,
    coalesce((select count(*) from public.orders o where o.provider_id = b.uid), 0)::int,
    b.created_at
  from base b
  order by b.created_at desc
  limit 5000;

  get diagnostics v_marked = row_count;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (
    auth.uid(),
    'export_users',
    null,
    jsonb_build_object(
      'rows_returned', v_marked,
      'search',        v_search,
      'role',          p_role
    )
  );
end;
$$;

revoke all on function public.admin_export_users(text, text) from public;
revoke all on function public.admin_export_users(text, text) from anon;
grant execute on function public.admin_export_users(text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Targeted custom messages (custom broadcast).
-- Recipients restricted to real app users (profiles). type='broadcast' so the
-- Flutter renderer (metadata-driven) and notify_push both work unchanged.
-- deep_link: null = open notifications page; 'home' = in-app home; or an
-- http(s) external URL. Anything else is rejected.
-- ---------------------------------------------------------------------------
create or replace function public.admin_send_targeted_messages(
  p_user_ids  uuid[],
  p_title     text,
  p_body      text,
  p_deep_link text default null
)
returns int
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_title     text := nullif(btrim(coalesce(p_title, '')), '');
  v_body      text := nullif(btrim(coalesce(p_body, '')), '');
  v_link      text := nullif(btrim(coalesce(p_deep_link, '')), '');
  v_ids       uuid[];
  v_metadata  jsonb;
  v_inserted  int := 0;
begin
  perform public.assert_admin();

  if v_title is null or char_length(v_title) > 100 then
    raise exception 'INVALID_TITLE';
  end if;
  if v_body is null or char_length(v_body) > 400 then
    raise exception 'INVALID_BODY';
  end if;
  if v_link is not null
     and v_link <> 'home'
     and v_link !~ '^https?://' then
    raise exception 'INVALID_DEEP_LINK';
  end if;
  if p_user_ids is null or array_length(p_user_ids, 1) is null
     or array_length(p_user_ids, 1) = 0 then
    raise exception 'NO_RECIPIENTS';
  end if;
  if array_length(p_user_ids, 1) > 5000 then
    raise exception 'TOO_MANY_RECIPIENTS';
  end if;
  v_ids := array(select distinct unnest(p_user_ids));

  v_metadata := jsonb_build_object(
    'title', v_title,
    'body',  v_body
  );
  if v_link is not null then
    v_metadata := jsonb_set(v_metadata, '{deep_link}', to_jsonb(v_link));
  end if;

  with target as (
    select pr.id
    from public.profiles pr
    where pr.id = any(v_ids)
  ), inserted as (
    insert into public.notifications (user_id, type, metadata)
    select t.id, 'broadcast', v_metadata
    from target t
    returning 1
  )
  select count(*)::int into v_inserted from inserted;
  get diagnostics v_inserted = row_count;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (
    auth.uid(),
    'send_targeted_messages',
    null,
    jsonb_build_object(
      'recipients', v_inserted,
      'requested',  array_length(v_ids, 1),
      'title',      v_title,
      'deep_link',  v_link
    )
  );

  return v_inserted;
end;
$$;

revoke all on function public.admin_send_targeted_messages(uuid[], text, text, text) from public;
revoke all on function public.admin_send_targeted_messages(uuid[], text, text, text) from anon;
grant execute on function public.admin_send_targeted_messages(uuid[], text, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Ban / unban. GoTrue blocks sign-in and token refresh while banned_until > now.
-- Reason is mandatory and audited. Admin accounts can never be banned.
-- ---------------------------------------------------------------------------
create or replace function public.admin_ban_user(p_user_id uuid, p_reason text)
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
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

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (auth.uid(), 'ban_user', p_user_id, jsonb_build_object('reason', v_reason));

  return (select banned_until from auth.users where id = p_user_id);
end;
$$;

revoke all on function public.admin_ban_user(uuid, text) from public;
revoke all on function public.admin_ban_user(uuid, text) from anon;
grant execute on function public.admin_ban_user(uuid, text) to authenticated, service_role;

create or replace function public.admin_unban_user(p_user_id uuid)
returns boolean
language plpgsql
volatile
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

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (auth.uid(), 'unban_user', p_user_id, jsonb_build_object());

  return true;
end;
$$;

revoke all on function public.admin_unban_user(uuid) from public;
revoke all on function public.admin_unban_user(uuid) from anon;
grant execute on function public.admin_unban_user(uuid) to authenticated, service_role;