-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20260828124744 | name: add_set_order_attachments
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
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
