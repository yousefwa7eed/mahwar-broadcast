-- =============================================================================
-- Reconstructed from the live DB (applied as migration "provider_attachments").
-- Adds support for the provider to attach photos (proof of work, etc.) to an order.
-- The edge function delete-order-attachments also clears this column on terminal
-- statuses, so it is nullable text[].
-- =============================================================================

alter table public.orders
  add column if not exists provider_attachments text[];
