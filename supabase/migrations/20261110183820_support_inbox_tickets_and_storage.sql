-- =============================================================================
-- In-app support inbox (item 10): tickets + private attachments + admin reply.
--
-- Threat model / السبب:
--   * الدعم الحالي يفتح mailto فلا يبقى أثر للرسالة، ولا يوجد صندوق للإدارة.
--   * الصورة المرفقة كانت ترفع على bucket عام (order-attachments) فرابط لقطة
--     شاشة قد تحمل رقم/لوحة ويصبح عامًا. هنا bucket خاص بسياسات مجلد المالك.
--   * submit_support_ticket مفتوحة لـ anon (الدعم لازم يشتغل قبل الدخول)،
--     فلذلك: تحقق صارم من الحقول، اشتقاق الاسم/الرقم من profiles للمسجل (لا
--     يُقبل أي رقم من العميل)، مرفقات للمسجل فقط وداخل مجلده، قفل استشاري
--     لكل هوية، وحدود معدل + كشف تكرار لتخفيف الإغراق.
--   * الجدول RLS + FORCE بلا أي policy وبدون أي صلاحية مباشرة: كل الوصول عبر
--     دوال SECURITY DEFINER فقط (نفس نمط جداول الأدمن).
-- =============================================================================

-- 1) Bucket خاص للمرفقات ------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'support-attachments', 'support-attachments', false, 10485760,
  array['image/jpeg','image/png','image/webp','image/heic','image/heif']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 2) سياسات التخزين: المسار الوحيد المسموح support/<uid>/<file> ------------------
drop policy if exists "Support attachment upload (own folder)" on storage.objects;
create policy "Support attachment upload (own folder)"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'support-attachments'
  and (storage.foldername(name))[1] = 'support'
  and array_length(storage.foldername(name), 1) = 2
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists "Support attachment owner read" on storage.objects;
create policy "Support attachment owner read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'support-attachments'
  and (storage.foldername(name))[1] = 'support'
  and (storage.foldername(name))[2] = auth.uid()::text
);

-- قراءة الأدمن لصور التذاكر (is_admin يشترط aal2 — جلسة اللوحة كذلك).
drop policy if exists "Support attachment admin read" on storage.objects;
create policy "Support attachment admin read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'support-attachments'
  and public.is_admin()
);

-- 3) جدول التذاكر -------------------------------------------------------------
create table if not exists public.support_tickets (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references auth.users(id) on delete set null,
  user_role       text,
  kind            text not null check (kind in ('complaint','suggestion','inquiry')),
  category        text,
  subject         text not null,
  body            text not null,
  contact_name    text not null,
  contact_phone   text not null,
  attachment_path text,
  status          text not null default 'open' check (status in ('open','replied','closed')),
  reply_body      text,
  replied_by      uuid,
  replied_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.support_tickets enable row level security;
alter table public.support_tickets force row level security;
revoke all on table public.support_tickets from public;
revoke all on table public.support_tickets from anon;
revoke all on table public.support_tickets from authenticated;

create index if not exists support_tickets_user_idx
  on public.support_tickets (user_id, created_at desc);
create index if not exists support_tickets_phone_idx
  on public.support_tickets (contact_phone, created_at desc);
create index if not exists support_tickets_status_idx
  on public.support_tickets (status, created_at desc);

-- 4) إنشاء تذكرة (متاحة للزائر وللمسجل) ---------------------------------------
create or replace function public.submit_support_ticket(
  p_kind            text,
  p_category        text default null,
  p_subject         text default null,
  p_body            text default null,
  p_contact_name    text default null,
  p_contact_phone   text default null,
  p_attachment_path text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_kind      text := lower(btrim(coalesce(p_kind, '')));
  v_category  text := nullif(btrim(coalesce(p_category, '')), '');
  v_subject   text := btrim(coalesce(p_subject, ''));
  v_body      text := btrim(coalesce(p_body, ''));
  v_name      text;
  v_phone     text;
  v_role      text;
  v_attach    text := nullif(btrim(coalesce(p_attachment_path, '')), '');
  v_existing  uuid;
  v_recent    int;
  v_id        uuid;
begin
  if v_kind not in ('complaint','suggestion','inquiry') then
    raise exception 'SUPPORT_INVALID_KIND';
  end if;
  if char_length(v_subject) < 3 or char_length(v_subject) > 120 then
    raise exception 'SUPPORT_INVALID_SUBJECT';
  end if;
  if char_length(v_body) < 10 or char_length(v_body) > 4000 then
    raise exception 'SUPPORT_INVALID_BODY';
  end if;
  if v_category is not null and char_length(v_category) > 80 then
    raise exception 'SUPPORT_INVALID_CATEGORY';
  end if;

  -- المسجل: الاسم/الرقم/الدور من profiles فقط (منع انتحال رقم أو اسم).
  if v_uid is not null then
    select nullif(btrim(p.full_name), ''),
           nullif(btrim(p.phone_number), ''),
           p.role::text
      into v_name, v_phone, v_role
    from public.profiles p
    where p.id = v_uid;
    v_name  := coalesce(v_name,  nullif(btrim(coalesce(p_contact_name, '')), ''));
    v_phone := coalesce(v_phone, nullif(btrim(coalesce(p_contact_phone, '')), ''));
  else
    v_name  := nullif(btrim(coalesce(p_contact_name, '')), '');
    v_phone := nullif(btrim(coalesce(p_contact_phone, '')), '');
    v_role  := null;
  end if;

  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'SUPPORT_INVALID_CONTACT';
  end if;
  if v_phone is null or v_phone !~ '^01[0-9]{9}$' then
    raise exception 'SUPPORT_INVALID_CONTACT';
  end if;

  -- مرفق للمسجل فقط وداخل مجلده support/<uid>/ — أي مسار آخر يُرفض.
  if v_attach is not null then
    if v_uid is null
       or v_attach !~ ('^support/' || v_uid::text || '/[A-Za-z0-9_-][A-Za-z0-9._-]*$') then
      raise exception 'SUPPORT_INVALID_ATTACHMENT';
    end if;
  end if;

  -- قفل لكل هوية: كشف التكرار والحدود لا يُتجاوزان بتزامن.
  perform pg_advisory_xact_lock(
    hashtextextended(coalesce(v_uid::text, 'anon:' || v_phone), 0)
  );

  -- دبل كليك: نفس الهوية ونفس النص خلال 10 دقايق → نفس التذكرة.
  select t.id into v_existing
  from public.support_tickets t
  where t.body = v_body
    and ((v_uid is not null and t.user_id = v_uid)
         or (v_uid is null and t.user_id is null and t.contact_phone = v_phone))
    and t.created_at > now() - interval '10 minutes'
  order by t.created_at desc
  limit 1;
  if v_existing is not null then
    return v_existing;
  end if;

  -- قاطع عام ضد الإغراق الآلي.
  select count(*) into v_recent
  from public.support_tickets
  where created_at > now() - interval '24 hours';
  if v_recent >= 500 then
    raise exception 'SUPPORT_RATE_LIMITED';
  end if;

  if v_uid is not null then
    select count(*) into v_recent
    from public.support_tickets
    where user_id = v_uid and created_at > now() - interval '24 hours';
    if v_recent >= 5 then
      raise exception 'SUPPORT_RATE_LIMITED';
    end if;
  else
    select count(*) into v_recent
    from public.support_tickets
    where user_id is null
      and contact_phone = v_phone
      and created_at > now() - interval '24 hours';
    if v_recent >= 3 then
      raise exception 'SUPPORT_RATE_LIMITED';
    end if;
  end if;

  insert into public.support_tickets (
    user_id, user_role, kind, category, subject, body,
    contact_name, contact_phone, attachment_path
  ) values (
    v_uid, v_role, v_kind, v_category, v_subject, v_body,
    v_name, v_phone, v_attach
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_support_ticket(text,text,text,text,text,text,text) from public;
grant execute on function public.submit_support_ticket(text,text,text,text,text,text,text)
  to anon, authenticated, service_role;

-- 5) تذاكر المستخدم -----------------------------------------------------------
create or replace function public.get_my_support_tickets(
  p_limit  integer default 20,
  p_offset integer default 0
)
returns table (
  id          uuid,
  kind        text,
  category    text,
  subject     text,
  body        text,
  status      text,
  reply_body  text,
  replied_at  timestamptz,
  created_at  timestamptz,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_limit  int := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset int := greatest(coalesce(p_offset, 0), 0);
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  return query
  select t.id, t.kind, t.category, t.subject, t.body, t.status,
         t.reply_body, t.replied_at, t.created_at,
         count(*) over () as total_count
  from public.support_tickets t
  where t.user_id = v_uid
  order by t.created_at desc, t.id desc
  limit v_limit offset v_offset;
end;
$$;

revoke all on function public.get_my_support_tickets(integer,integer) from public;
revoke all on function public.get_my_support_tickets(integer,integer) from anon;
grant execute on function public.get_my_support_tickets(integer,integer)
  to authenticated, service_role;

-- 6) صندوق الإدارة ------------------------------------------------------------
create or replace function public.admin_list_support_tickets(
  p_status    text default null,
  p_search    text default null,
  p_page      int default 1,
  p_page_size int default 25
)
returns table (
  id             uuid,
  kind           text,
  category       text,
  subject        text,
  contact_name   text,
  contact_phone  text,
  status         text,
  user_id        uuid,
  user_role      text,
  has_attachment boolean,
  created_at     timestamptz,
  replied_at     timestamptz,
  total_count    bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_page   int  := greatest(coalesce(p_page, 1), 1);
  v_size   int  := least(greatest(coalesce(p_page_size, 25), 1), 100);
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
begin
  perform public.assert_admin();

  if v_status is not null and v_status not in ('open','replied','closed') then
    raise exception 'SUPPORT_INVALID_STATUS';
  end if;

  return query
  select t.id, t.kind, t.category, t.subject, t.contact_name, t.contact_phone,
         t.status, t.user_id, t.user_role,
         (t.attachment_path is not null) as has_attachment,
         t.created_at, t.replied_at,
         count(*) over () as total_count
  from public.support_tickets t
  where (v_status is null or t.status = v_status)
    and (v_search is null
         or t.contact_name  ilike '%' || v_search || '%'
         or t.contact_phone ilike '%' || v_search || '%'
         or t.subject       ilike '%' || v_search || '%'
         or t.body          ilike '%' || v_search || '%')
  order by t.created_at desc, t.id desc
  limit v_size offset (v_page - 1) * v_size;
end;
$$;

revoke all on function public.admin_list_support_tickets(text,text,int,int) from public;
revoke all on function public.admin_list_support_tickets(text,text,int,int) from anon;
grant execute on function public.admin_list_support_tickets(text,text,int,int)
  to authenticated, service_role;

create or replace function public.admin_get_support_ticket(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row jsonb;
begin
  perform public.assert_admin();

  select jsonb_build_object(
    'id', t.id,
    'kind', t.kind,
    'category', t.category,
    'subject', t.subject,
    'body', t.body,
    'contact_name', t.contact_name,
    'contact_phone', t.contact_phone,
    'attachment_path', t.attachment_path,
    'status', t.status,
    'reply_body', t.reply_body,
    'replied_at', t.replied_at,
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'user', case
      when t.user_id is null then null
      else jsonb_build_object(
        'id', t.user_id,
        'full_name', p.full_name,
        'phone_number', p.phone_number,
        'role', t.user_role
      )
    end
  )
  into v_row
  from public.support_tickets t
  left join public.profiles p on p.id = t.user_id
  where t.id = p_ticket_id;

  if v_row is null then
    raise exception 'SUPPORT_TICKET_NOT_FOUND';
  end if;

  return v_row;
end;
$$;

revoke all on function public.admin_get_support_ticket(uuid) from public;
revoke all on function public.admin_get_support_ticket(uuid) from anon;
grant execute on function public.admin_get_support_ticket(uuid)
  to authenticated, service_role;

create or replace function public.admin_reply_support_ticket(
  p_ticket_id uuid,
  p_reply_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_body text := btrim(coalesce(p_reply_body, ''));
  v_status text;
begin
  perform public.assert_admin();

  if char_length(v_body) < 2 or char_length(v_body) > 4000 then
    raise exception 'SUPPORT_INVALID_BODY';
  end if;

  select t.status into v_status
  from public.support_tickets t
  where t.id = p_ticket_id;

  if v_status is null then
    raise exception 'SUPPORT_TICKET_NOT_FOUND';
  end if;
  if v_status = 'closed' then
    raise exception 'SUPPORT_TICKET_CLOSED';
  end if;

  update public.support_tickets
  set reply_body = v_body,
      status     = 'replied',
      replied_by = auth.uid(),
      replied_at = now(),
      updated_at = now()
  where id = p_ticket_id;
end;
$$;

revoke all on function public.admin_reply_support_ticket(uuid,text) from public;
revoke all on function public.admin_reply_support_ticket(uuid,text) from anon;
grant execute on function public.admin_reply_support_ticket(uuid,text)
  to authenticated, service_role;

create or replace function public.admin_set_support_status(
  p_ticket_id uuid,
  p_status    text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := lower(btrim(coalesce(p_status, '')));
begin
  perform public.assert_admin();

  if v_status not in ('open','replied','closed') then
    raise exception 'SUPPORT_INVALID_STATUS';
  end if;

  update public.support_tickets
  set status     = v_status,
      updated_at = now()
  where id = p_ticket_id;

  if not found then
    raise exception 'SUPPORT_TICKET_NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.admin_set_support_status(uuid,text) from public;
revoke all on function public.admin_set_support_status(uuid,text) from anon;
grant execute on function public.admin_set_support_status(uuid,text)
  to authenticated, service_role;
