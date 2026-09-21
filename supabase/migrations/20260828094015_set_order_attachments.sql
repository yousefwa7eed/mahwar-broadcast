-- =============================================================================
-- Reconstructed from the live DB (applied as migration "set_order_attachments").
-- Lets the ORDER OWNER attach uploaded image URLs to their order.
-- Orders have no UPDATE client policies, so this goes through a SECURITY
-- DEFINER RPC that only updates rows owned by the caller (auth.uid()).
-- Empty search path avoids search-path hijacking.
-- =============================================================================

drop function if exists public.set_order_attachments(uuid, text[]);

create or replace function public.set_order_attachments(
  p_order_id    uuid,
  p_attachments text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.orders
  set attachments = p_attachments,
      updated_at  = now()
  where id = p_order_id
    and car_owner_id = auth.uid();

  if not found then
    raise exception 'ORDER_NOT_FOUND_OR_FORBIDDEN';
  end if;
end;
$$;
