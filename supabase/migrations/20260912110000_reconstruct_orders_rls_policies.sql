-- =============================================================================
-- Reconstruct the orders RLS policies in the migration tree.
--
-- Problem: the two policies that protect the orders table (create/view)
-- existed ONLY in the live database (created ad-hoc), never in any migration
-- file. A fresh environment built from these migrations (db reset / new
-- branch / new project) would ship orders WITHOUT the INSERT + SELECT
-- policies, leaving them readable/writable by no one except the bypassing
-- owner — a silent security hole that only surfaces after two environments
-- drift apart.
--
-- Solution: recreate exactly the live policies here, idempotently (guarded by
-- existence checks on pg_policy), so the repo is the single source of truth
-- and re-running on any environment converges to the same state.
-- NOTE: PostgreSQL has no CREATE POLICY IF NOT EXISTS; the DO blocks below
-- emulate it and stay purely additive (no drop/recreate churn).
--
-- Verified against the live DB (pg_policy):
--   'Car owners create orders'  INSERT, roles {public},
--                              WITH CHECK (auth.uid() = car_owner_id)
--   'Users view relevant orders' SELECT, roles {public},
--                              USING (auth.uid() = car_owner_id
--                                     OR auth.uid() = provider_id)
-- No UPDATE/DELETE policy on purpose: state transitions happen exclusively
-- through SECURITY DEFINER RPCs (owner_accept_price, owner_reject_order,
-- owner_cancel_order, provider_set_price, provider_reject_order,
-- assign_order_to_provider, expire-pending-orders cron).
-- =============================================================================

alter table public.orders enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'orders'
      and p.polname = 'Car owners create orders'
  ) then
    create policy "Car owners create orders"
      on public.orders
      as permissive
      for insert
      to public
      with check (auth.uid() = car_owner_id);
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'orders'
      and p.polname = 'Users view relevant orders'
  ) then
    create policy "Users view relevant orders"
      on public.orders
      as permissive
      for select
      to public
      using (auth.uid() = car_owner_id or auth.uid() = provider_id);
  end if;
end;
$$;