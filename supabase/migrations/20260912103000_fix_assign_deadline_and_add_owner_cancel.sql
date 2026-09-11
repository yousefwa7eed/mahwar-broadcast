-- =============================================================================
-- P0 fix: assign_order_to_provider + new owner_cancel_order.
--
-- Problem (bug 1): assign_order_to_provider never sets respond_deadline, so the
-- expire-pending-orders cron (which only looks at respond_deadline < now())
-- can never expire these orders. 12+ orders in the live DB are stuck in
-- 'pending' forever with respond_deadline = NULL.
--
-- Solution: the same function now stamps respond_deadline = now() + 3 minutes
-- at assignment time. It ALSO becomes atomic: the UPDATE carries a
-- WHERE provider_id IS NULL AND status = 'pending' guard, so two concurrent
-- assignments (owner double-tap) cannot both claim the order — the second one
-- updates zero rows and raises ORDER_NOT_PENDING instead of silently
-- re-assigning a hot order.
--
-- Problem (bug 2): car owners have no way to cancel a pending order. The only
-- cancellation path was the cron, so an owner stuck waiting forever had to ride
-- it out or watch the request spin.
--
-- Solution: new owner_cancel_order(p_order_id) RPC — owner-only, atomic
-- pending -> cancelled, notifies the assigned provider (if any) with an
-- 'order_cancelled' notification (by = 'owner'), and the existing
-- order_terminal_cleanup trigger handles storage cleanup.
-- =============================================================================

-- 1) Atomic assign + deadline.
drop function if exists public.assign_order_to_provider(uuid, uuid);
create or replace function public.assign_order_to_provider(p_order_id uuid, p_provider_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner      uuid;
  v_service    text;
  v_status     public.order_status;
  v_provider   uuid;
  v_affected   int;
begin
  select car_owner_id, service_type_id, status, provider_id
    into v_owner, v_service, v_status, v_provider
  from public.orders where id = p_order_id;

  if v_owner is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  if v_owner <> auth.uid() then
    raise exception 'NOT_OWNER';
  end if;

  -- Atomic claim: only a still-pending, still-unassigned order can be taken.
  -- A concurrent assign (double-tap) updates 0 rows and we raise below.
  update public.orders
  set provider_id = p_provider_id,
      respond_deadline = now() + interval '3 minutes',
      updated_at = now()
  where id = p_order_id
    and status = 'pending'
    and provider_id is null;

  get diagnostics v_affected = row_count;
  if v_affected = 0 then
    raise exception 'ORDER_NOT_PENDING';
  end if;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    p_provider_id,
    p_order_id,
    'new_order',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service)
    )
  );
end;
$$;

grant execute on function public.assign_order_to_provider(uuid, uuid) to authenticated;

-- 2) Owner cancels a pending order (before/without provider response).
create or replace function public.owner_cancel_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner    uuid;
  v_provider uuid;
  v_service  text;
  v_affected int;
begin
  select car_owner_id, provider_id, service_type_id
    into v_owner, v_provider, v_service
  from public.orders where id = p_order_id;

  if v_owner is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  if v_owner <> auth.uid() then
    raise exception 'NOT_OWNER';
  end if;

  -- Atomic: only a pending order can be cancelled; if the cron just expired it,
  -- 0 rows are updated and we raise instead of clobbering the timeout state.
  update public.orders
  set status = 'cancelled',
      respond_deadline = null,
      updated_at = now()
  where id = p_order_id
    and status = 'pending';

  get diagnostics v_affected = row_count;
  if v_affected = 0 then
    raise exception 'ORDER_NOT_PENDING';
  end if;

  -- Tell the assigned provider (if any) the job is off — by = 'owner'
  -- so the app can distinguish it from a timeout cancellation.
  if v_provider is not null then
    insert into public.notifications (user_id, order_id, type, metadata)
    values (
      v_provider,
      p_order_id,
      'order_cancelled',
      jsonb_build_object(
        'service_type_id', v_service,
        'service_name', (select name_ar from public.service_types st where st.id = v_service),
        'by', 'owner'
      )
    );
  end if;
end;
$$;

grant execute on function public.owner_cancel_order(uuid) to authenticated;