-- =============================================================================
-- Section A: harden the "order-attachments" storage bucket.
-- Date: 2026-10-13
--
-- Findings (read-only, live):
--   * Bucket "order-attachments" is PUBLIC (kept public) with NO size/mime
--     limits.
--   * INSERT had a permissive policy ("Allow Authenticated Uploads": only
--     bucket_id = 'order-attachments'), so ANY authenticated user could write
--     ANYWHERE in the bucket. The scoped policy existed but tested
--     foldername(name)[1] (= 'orders'), never the uid -> always false.
--   * DELETE ("Allow Individual Delete") also tested foldername[1] -> nobody
--     could delete their own files from the client (the provider rollback
--     delete silently failed).
--   * Real path convention (code + live objects): orders/<uid>/<file>, so the
--     uid is foldername(name)[2], NOT [1]. Two legitimate writers:
--       - the order OWNER, under orders/<their own uid>/      (service_request)
--       - the ASSIGNED PROVIDER, also under orders/<car_owner_id>/ (provider
--         uploads before provider_set_price, which requires
--         provider_id = auth.uid(), so the assignment exists at upload time).
--   * Audit of existing orders.attachments + provider_attachments: every URL is
--     under its own owner prefix and none contains traversal (0 rows returned).
--
-- This migration:
--   1) Adds bucket size + mime limits (bucket stays public).
--   2) Replaces the permissive INSERT with a scoped rule: own folder OR
--      assigned provider of that owner.
--   3) Fixes DELETE to the same rule.
--   4) Hardens public.set_order_attachments to reject any URL that is not a
--      public object URL for THIS bucket under the caller's orders/<uid>/
--      prefix (rejects traversal / encoded traversal / foreign paths).
-- =============================================================================

-- 1) Bucket limits (bucket stays public) -------------------------------------
update storage.buckets
set file_size_limit    = 10485760,  -- 10 MiB
    allowed_mime_types = array[
      'image/jpeg','image/png','image/webp','image/heic','image/heif'
    ]
where id = 'order-attachments';

-- 2) INSERT ------------------------------------------------------------------
drop policy if exists "Allow Authenticated Uploads"    on storage.objects;
drop policy if exists "Scoped user attachment upload"  on storage.objects;

create policy "Scoped user attachment upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-attachments'
  and (
    (storage.foldername(name))[2] = auth.uid()::text
    or exists (
      select 1
      from public.orders o
      where o.provider_id = auth.uid()
        and o.car_owner_id::text = (storage.foldername(name))[2]
    )
  )
);

-- 3) DELETE ------------------------------------------------------------------
drop policy if exists "Allow Individual Delete" on storage.objects;

create policy "Allow Individual Delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-attachments'
  and (
    (storage.foldername(name))[2] = auth.uid()::text
    or exists (
      select 1
      from public.orders o
      where o.provider_id = auth.uid()
        and o.car_owner_id::text = (storage.foldername(name))[2]
    )
  )
);

-- 4) Validated set_order_attachments -----------------------------------------
-- Same signature/ACL (create-or-replace keeps grants). Extra guard: every
-- stored URL must be a public object URL for this bucket under
-- orders/<caller-uid>/ and the trailing name must be a single path segment.
create or replace function public.set_order_attachments(
  p_order_id    uuid,
  p_attachments text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner  uuid;
  v_marker text;
  v_url    text;
  v_idx    int;
  v_tail   text;
begin
  select car_owner_id into v_owner
  from public.orders
  where id = p_order_id
    and car_owner_id = auth.uid();

  if v_owner is null then
    raise exception 'ORDER_NOT_FOUND_OR_FORBIDDEN';
  end if;

  v_marker := '/storage/v1/object/public/order-attachments/orders/' || v_owner::text || '/';

  foreach v_url in array coalesce(p_attachments, '{}'::text[]) loop
    if v_url is null then
      raise exception 'INVALID_ATTACHMENT_URL';
    end if;

    -- reject traversal, backslashes, and percent-encoding tricks
    if position('..' in v_url) > 0
       or position(chr(92) in v_url) > 0
       or v_url ~* '(%2e|%2f|%5c)' then
      raise exception 'INVALID_ATTACHMENT_URL';
    end if;

    v_idx := position(v_marker in v_url);
    if v_idx = 0 then
      raise exception 'INVALID_ATTACHMENT_URL';
    end if;

    v_tail := substring(v_url from v_idx + length(v_marker));
    v_tail := split_part(v_tail, '?', 1);
    v_tail := split_part(v_tail, '#', 1);
    if v_tail = '' or position('/' in v_tail) > 0 then
      raise exception 'INVALID_ATTACHMENT_URL';
    end if;
  end loop;

  update public.orders
  set attachments = p_attachments,
      updated_at  = now()
  where id = p_order_id
    and car_owner_id = auth.uid();
end;
$$;
