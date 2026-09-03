-- =============================================================================
-- Harden order state transitions.
-- Guards provider_set_price / provider_reject_order so they only act on an
-- order that is still assigned-and-pending. Previously a provider could price
-- or reject an order AFTER it was already cancelled (e.g. by the
-- expire-pending-orders cron), completed, confirmed, or otherwise moved past
-- the pending state, corrupting the order lifecycle and re-notifying the owner.
--
-- NOTE: the live DB had two provider_set_price signatures. The app calls the
-- 5-arg one (adds provider attachments). We harden that one, and drop the
-- legacy 2-arg variant (dead code, emits an 'order_priced' type the app does
-- not consume).
-- =============================================================================

-- 1) Drop legacy 2-arg provider_set_price (superseded, unused by the app).
drop function if exists public.provider_set_price(uuid, numeric);

-- 2) Hardened provider_set_price (5-arg, matches the app's invocation):
--    only allow `pending` (assigned) -> `priced`.
drop function if exists public.provider_set_price(uuid, numeric, text, integer, text[]);
create or replace function public.provider_set_price(
  p_order_id uuid,
  p_price numeric,
  p_notes text default null,
  p_eta_minutes integer default null,
  p_attachments text[] default null
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_owner   uuid;
  v_service text;
  v_status  public.order_status;
  v_row     public.orders;
begin
  select provider_id, car_owner_id, service_type_id, status
    into v_provider, v_owner, v_service, v_status
  from public.orders where id = p_order_id;

  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;
  if v_provider <> auth.uid() then
    raise exception 'NOT_PROVIDER';
  end if;
  if v_status <> 'pending' then
    raise exception 'ORDER_NOT_PENDING';
  end if;
  if p_price is null or p_price <= 0 then
    raise exception 'INVALID_PRICE';
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

grant execute on function public.provider_set_price(uuid, numeric, text, integer, text[]) to authenticated;

-- 3) Hardened provider_reject_order: only allow `pending` (assigned) -> `rejected_by_provider`.
drop function if exists public.provider_reject_order(uuid);
create or replace function public.provider_reject_order(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_owner   uuid;
  v_service text;
  v_status  public.order_status;
  v_row     public.orders;
begin
  select provider_id, car_owner_id, service_type_id, status
    into v_provider, v_owner, v_service, v_status
  from public.orders where id = p_order_id;

  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;
  if v_provider <> auth.uid() then
    raise exception 'NOT_PROVIDER';
  end if;
  if v_status <> 'pending' then
    raise exception 'ORDER_NOT_PENDING';
  end if;

  update public.orders
  set status = 'rejected_by_provider', updated_at = now()
  where id = p_order_id
  returning * into v_row;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_owner,
    p_order_id,
    'order_rejected',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service),
      'by', 'provider'
    )
  );

  return v_row;
end;
$$;

grant execute on function public.provider_reject_order(uuid) to authenticated;