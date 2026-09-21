-- Migration: Harden order state transitions (H1 sub-fix 3).
-- Date: 2026-09-18
--
-- Re-applies the hardening from the never-applied 20260902120000 migration,
-- with the ownership guard rewritten to the IS DISTINCT FROM form (H1
-- sub-fix 2) so it composes with live state. Adds the missing status
-- precondition so provider_set_price / provider_reject_order only act on an
-- order that is still `pending` (assigned). Previously a provider could price
-- or reject an order AFTER cancellation/completion, corrupting the lifecycle
-- and re-notifying the owner.
--
-- The legacy 2-arg provider_set_price is dropped separately in H1 sub-fix 4.

-- provider_set_price (5-arg): pending -> priced only.
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
  if auth.uid() is null or v_provider is distinct from auth.uid() then
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

-- provider_reject_order: pending -> rejected_by_provider only.
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
  if auth.uid() is null or v_provider is distinct from auth.uid() then
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