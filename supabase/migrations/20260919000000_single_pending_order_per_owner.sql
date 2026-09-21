-- =============================================================================
-- One active (pending) order per car_owner — DB-level guard + edit-in-place RPC
--
-- Problem (Mahwar issue #7):
--   service_request_screen inserts a fresh `orders` row on every submit with no
--   check for an existing pending order, and nothing in the DB rejects it: the
--   INSERT policy allows unlimited rows per owner. A customer could end up with
--   several orphaned `pending` orders (no provider) while providers bid on all
--   of them — a duplicate-request bug. It also forced the client to `go()` from
--   the provider-selection screen (replacing the whole stack), which is why the
--   back button there appeared broken: there was nothing left to pop back to.
--
-- Fix (two coherent layers):
--   1) Physical guard: a partial unique index on orders(car_owner_id) scoped to
--      `status = 'pending'` makes PostgreSQL itself reject a second pending order
--      for the same owner, from ANY client path (app UI, direct API, script).
--   2) Edit-in-place: orders have NO client UPDATE policy by design (state
--      transitions run through SECURITY DEFINER RPCs). This migration adds
--      update_pending_order(), which lets the owner update the editable fields
--      (car, location, notes, preferences, service) of their OWN pending order.
--      The client reuses this RPC instead of inserting a duplicate, and now
--      navigates to the provider list with push() so the back arrow returns to
--      the pre-filled form.
--
-- Race handling: if the app-level "does a pending order exist?" check races
-- (another path inserts between the check and the insert), the insert throws
-- SQLSTATE 23505; the client catches it and falls back to update_pending_order
-- on the re-fetched row — no raw DB error ever reaches the user.
-- =============================================================================

-- 1) Physical guard: at most one pending order per car_owner.
create unique index if not exists orders_single_pending_per_owner
  on public.orders (car_owner_id)
  where status = 'pending';

-- 2) Edit-in-place RPC for the owner's own pending order.
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
         -- Mirror trg_orders_apply_cancel_prefs (insert-time) for updates so the
         -- auto-cancel window restarts when the customer edits the pending order.
         respond_deadline = case when p_auto_cancel then now() + interval '5 minutes' else null end,
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

revoke execute on function public.update_pending_order(uuid, text, text, text, integer, double precision, double precision, text, text, boolean, boolean) from public, anon;