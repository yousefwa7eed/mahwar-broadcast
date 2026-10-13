-- =============================================================================
-- Section A follow-up: tighten attachment storage policies + validate stored
-- URLs at every write path.
-- Date: 2026-10-13
--
-- Scope (ONLY these):
--   GAP 1 - storage.objects policies were too wide:
--     * DELETE let an assigned provider delete ANY file in the owner's folder
--       (and the rule kept working for finished orders). Target: only the
--       uploader may delete what they uploaded -> owner_id = auth.uid()::text.
--       (Live column type: storage.objects.owner_id is `text`; the 3 real
--        objects all have owner_id = their uploader uid, so their uploader can
--        still delete them. Provider rollback remove() is covered because the
--        provider is the uploader of its own files.)
--     * INSERT accepted any path. Target: exactly orders/<uid>/<file>
--       (foldername[1]='orders', array_length(foldername,1)=2) AND either
--       foldername[2] = auth.uid()::text (owner) OR the caller is the assigned
--       provider of that owner AND the order status = 'pending'.
--       Verified: provider uploads happen ONLY in the offer-price flow, whose
--       RPC provider_set_price requires status='pending'; so 'pending' is safe.
--     * No UPDATE / upsert policy is added.
--   GAP 2 - set_order_attachments only matched the marker substring, so any
--       host passed. Add one shared IMMUTABLE helper that checks the exact
--       https://<ref>.supabase.co origin + path shape, and use it here.
--       Client stores getPublicUrl(orders/<uid>/<file>) verbatim:
--       https://trgesfzojaoirutkkfcs.supabase.co/storage/v1/object/public/
--       order-attachments/orders/<uid>/<file>   (no query string / fragment).
--   GAP 3 - provider_set_price stored provider_attachments unvalidated. Validate
--       every element with the same helper (p_owner = v_owner).
--
-- Attachment array cap: the Flutter client enforces NO maximum (single pick,
-- appended). Per product decision the server caps the array at 10 items; NULL
-- or empty arrays stay allowed.
-- =============================================================================

-- 1) Shared URL validator -----------------------------------------------------
create or replace function public.is_valid_order_attachment(
  p_url   text,
  p_owner uuid
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (p_owner is not null)
     and (p_url is not null)
     and (p_url ~
          ('^https://trgesfzojaoirutkkfcs\.supabase\.co/storage/v1/object/public/order-attachments/orders/'
            || p_owner::text
            || '/[A-Za-z0-9_-][A-Za-z0-9._-]*$'));
$$;

revoke execute on function public.is_valid_order_attachment(text, uuid) from public;
revoke execute on function public.is_valid_order_attachment(text, uuid) from anon;
grant execute on function public.is_valid_order_attachment(text, uuid) to authenticated;
grant execute on function public.is_valid_order_attachment(text, uuid) to service_role;

-- 2) INSERT -------------------------------------------------------------------
drop policy if exists "Scoped user attachment upload"  on storage.objects;
drop policy if exists "Allow Authenticated Uploads"    on storage.objects;

create policy "Scoped user attachment upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-attachments'
  and (storage.foldername(name))[1] = 'orders'
  and array_length(storage.foldername(name), 1) = 2
  and (
    (storage.foldername(name))[2] = auth.uid()::text
    or exists (
      select 1
      from public.orders o
      where o.provider_id = auth.uid()
        and o.car_owner_id::text = (storage.foldername(name))[2]
        and o.status = 'pending'
    )
  )
);

-- 3) DELETE (uploader-only) ---------------------------------------------------
drop policy if exists "Allow Individual Delete" on storage.objects;

create policy "Allow Individual Delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-attachments'
  and owner_id = auth.uid()::text
);

-- 4) set_order_attachments ----------------------------------------------------
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
  v_owner uuid;
  v_url   text;
begin
  select car_owner_id into v_owner
  from public.orders
  where id = p_order_id
    and car_owner_id = auth.uid();

  if v_owner is null then
    raise exception 'ORDER_NOT_FOUND_OR_FORBIDDEN';
  end if;

  if coalesce(array_length(p_attachments, 1), 0) > 10 then
    raise exception 'TOO_MANY_ATTACHMENTS';
  end if;

  if p_attachments is not null then
    foreach v_url in array p_attachments loop
      if not public.is_valid_order_attachment(v_url, v_owner) then
        raise exception 'INVALID_ATTACHMENT_URL';
      end if;
    end loop;
  end if;

  update public.orders
  set attachments = p_attachments,
      updated_at  = now()
  where id = p_order_id
    and car_owner_id = auth.uid();
end;
$$;

-- 5) provider_set_price (add URL + length validation only) --------------------
create or replace function public.provider_set_price(
  p_order_id     uuid,
  p_price        numeric,
  p_notes        text DEFAULT NULL::text,
  p_eta_minutes  integer DEFAULT NULL::integer,
  p_attachments  text[] DEFAULT NULL::text[]
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_owner    uuid;
  v_service  text;
  v_status   public.order_status;
  v_row      public.orders;
  v_url      text;
begin
  select provider_id, car_owner_id, service_type_id, status
    into v_provider, v_owner, v_service, v_status
  from public.orders where id = p_order_id;

  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;
  if auth.uid() is null or v_provider is distinct from auth.uid() then
    raise exception 'NOT_PROVIDER';
  end if;
  if v_status <> 'pending' then
    raise exception 'ORDER_NOT_PENDING';
  end if;
  if p_price is null or p_price <= 0 then
    raise exception 'INVALID_PRICE';
  end if;

  if coalesce(array_length(p_attachments, 1), 0) > 10 then
    raise exception 'TOO_MANY_ATTACHMENTS';
  end if;

  if p_attachments is not null then
    foreach v_url in array p_attachments loop
      if not public.is_valid_order_attachment(v_url, v_owner) then
        raise exception 'INVALID_ATTACHMENT_URL';
      end if;
    end loop;
  end if;

  update public.orders
  set status = 'priced',
      offered_price = p_price,
      provider_notes = p_notes,
      eta_minutes = p_eta_minutes,
      provider_attachments = p_attachments,
      updated_at = now()
  where id = p_order_id
  returning * into v_row;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_owner,
    p_order_id,
    'price_offer',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service),
      'price', p_price,
      'provider_notes', p_notes,
      'eta_minutes', p_eta_minutes,
      'attachments', coalesce(p_attachments, '{}')
    )
  );

  return v_row;
end;
$$;
