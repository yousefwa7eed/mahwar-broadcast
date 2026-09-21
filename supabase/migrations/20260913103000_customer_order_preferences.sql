-- =============================================================================
-- Customer order preferences:
--   1) auto_cancel  (default true): the CUSTOMER decides at creation whether the
--      order auto-cancels after 5 minutes. Replaces the old fixed 3-minute
--      respond_deadline that was stamped at assignment time.
--   2) share_phone  (default false): the customer decides whether the assigned
--      provider may see / call the owner's phone number.
--
-- respond_deadline (existing column) is REUSED as "auto-cancel at [time]" —
-- it is no longer set by assign_order_to_provider. It is derived at INSERT from
-- the customer's choice (enabled -> now() + 5 minutes, disabled -> NULL).
-- =============================================================================

-- 1) New columns.
alter table public.orders add column if not exists auto_cancel boolean not null default true;
alter table public.orders add column if not exists share_phone boolean not null default false;

-- 2) Derive the auto-cancel deadline from the customer's choice at INSERT time.
create or replace function public.orders_apply_cancel_prefs()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.auto_cancel is true then
    new.respond_deadline := coalesce(new.respond_deadline, now() + interval '5 minutes');
  else
    new.respond_deadline := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_apply_cancel_prefs on public.orders;
create trigger trg_orders_apply_cancel_prefs
  before insert on public.orders
  for each row execute function public.orders_apply_cancel_prefs();

-- Trigger-only function: not meant to be callable via /rest/v1/rpc/...
-- (revoking EXECUTE does not affect trigger invocation).
revoke execute on function public.orders_apply_cancel_prefs() from public, authenticated;

-- 3) Assign no longer stamps a 3-minute deadline; the deadline (if any) was
--    decided by the customer at creation time.
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

  if v_owner <> auth.uid() then
    raise exception 'NOT_OWNER';
  end if;

  update public.orders
  set provider_id = p_provider_id,
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