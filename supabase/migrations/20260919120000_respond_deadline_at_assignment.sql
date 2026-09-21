-- =============================================================================
-- Move the auto-cancel countdown to the assignment moment
--
-- Problem (Mahwar item 3, diagnosis):
--   respond_deadline was derived at INSERT time by orders_apply_cancel_prefs
--   (now() + 5 minutes when auto_cancel is true), so a pending order's 5-minute
--   countdown started while the customer was still picking a provider — before
--   any provider had even seen the order. Providers can only see an order after
--   assign_order_to_provider stamps provider_id (provider home filters on
--   provider_id), so "the order reached the provider" == assignment.
--
-- Fix:
--   1) orders_apply_cancel_prefs (BEFORE INSERT trigger) no longer stamps a
--      deadline. It now FORCES respond_deadline = NULL at insert, which also
--      blocks a client from smuggling an early/absent deadline through a direct
--      orders insert.
--   2) assign_order_to_provider is now the single place that stamps
--      respond_deadline: at the moment the order is assigned to a provider,
--      now() + 5 minutes when auto_cancel is true, else NULL.
--   3) update_pending_order (20260919000000) stopped restarting the window on
--      edit. Under the new semantics, editing a pending order neither starts
--      (pre-assignment) nor restarts (assigned) the countdown.
--   4) expire_overdue_orders is UNCHANGED: its shared-field fallback
--      (respond_deadline IS NULL AND created_at < now() - interval '5 minutes')
--      still auto-cancels auto_cancel orders that were never assigned, so
--      orphaned pending orders cannot linger forever.
-- =============================================================================

-- 1) INSERT trigger: no deadline at creation, ever.
create or replace function public.orders_apply_cancel_prefs()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- No deadline at INSERT: respond_deadline is stamped only when the order is
  -- assigned to a provider (assign_order_to_provider). Forcing NULL here also
  -- prevents a client from setting an early deadline on a direct insert.
  new.respond_deadline := null;
  return new;
end;
$$;

-- 2) Assignment is now the single deadline stamp point.
drop function if exists public.assign_order_to_provider(uuid, uuid);
create or replace function public.assign_order_to_provider(p_order_id uuid, p_provider_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner    uuid;
  v_service  text;
  v_provider uuid;
  v_affected int;
begin
  select car_owner_id, service_type_id, provider_id
    into v_owner, v_service, v_provider
  from public.orders where id = p_order_id;

  if v_owner is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  if auth.uid() is null or v_owner is distinct from auth.uid() then
    raise exception 'NOT_OWNER';
  end if;

  update public.orders
  set provider_id = p_provider_id,
      -- The countdown starts when the order actually reaches the provider.
      respond_deadline = case
        when auto_cancel then now() + interval '5 minutes'
        else null
      end,
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

-- Dropping + recreating the function resets its ACL to the project-wide
-- function default (which includes PUBLIC + anon EXECUTE, via
-- ALTER DEFAULT PRIVILEGES). Re-harden explicitly, mirroring
-- 20260918070000_revoke_anon_order_lifecycle_rpcs.sql.
revoke all on function public.assign_order_to_provider(uuid, uuid) from public;
revoke all on function public.assign_order_to_provider(uuid, uuid) from anon;
revoke all on function public.assign_order_to_provider(uuid, uuid) from service_role;
grant execute on function public.assign_order_to_provider(uuid, uuid) to authenticated;
grant execute on function public.assign_order_to_provider(uuid, uuid) to service_role;

-- 3) Editing a pending order no longer touches the deadline (no start before
--    assignment, no restart after assignment).
create or replace function public.update_pending_order(
  p_order_id        uuid,
  p_service_type_id text,
  p_car_make        text,
  p_car_model       text,
  p_car_year        integer,
  p_latitude        double precision,
  p_longitude       double precision,
  p_notes           text,
  p_owner_phone     text,
  p_auto_cancel     boolean,
  p_share_phone     boolean
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.orders;
begin
  update public.orders
     set service_type_id  = p_service_type_id,
         car_make         = p_car_make,
         car_model        = p_car_model,
         car_year         = p_car_year,
         latitude         = p_latitude,
         longitude        = p_longitude,
         notes            = p_notes,
         owner_phone      = p_owner_phone,
         auto_cancel      = p_auto_cancel,
         share_phone      = p_share_phone,
         updated_at       = now()
   where id = p_order_id
     and car_owner_id = auth.uid()
     and status = 'pending'
   returning * into v_row;

  if v_row.id is null then
    raise exception 'ORDER_NOT_FOUND_OR_NOT_PENDING';
  end if;

  return v_row;
end;
$$;

grant execute on function public.update_pending_order(uuid, text, text, text, integer, double precision, double precision, text, text, boolean, boolean) to authenticated;

-- 4) Hyiene pass 20260918170000 re-granted authenticated EXECUTE on every
--    trigger helper; this trigger-only function is never callable via
--    /rest/v1/rpc (it returns `trigger`), so the grant is pure surface.
revoke execute on function public.orders_apply_cancel_prefs() from authenticated;

-- expire_overdue_orders is intentionally left unchanged (see header).