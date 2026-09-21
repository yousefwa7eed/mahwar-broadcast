-- Migration: tighten orders INSERT policy (H3).
-- Date: 2026-09-18
--
-- The INSERT policy only checked `car_owner_id = auth.uid()`. A client could
-- set arbitrary `status` (e.g. 'completed'), `provider_id`, and provider-owned
-- fields at creation — enabling fabricated completed orders that feed the
-- rating attack (H2) and letting a caller self-assign/publish a "priced"
-- order. Orders must only ever be created as fresh, unassigned, pending rows.

drop policy if exists "Car owners create orders" on public.orders;

create policy "Car owners create orders"
on public.orders
for insert
to public
with check (
  auth.uid() = car_owner_id
  and status = 'pending'::order_status
  and provider_id is null
  and offered_price is null
  and provider_notes is null
  and eta_minutes is null
  and provider_attachments is null
);