-- =============================================================================
-- Defence-in-depth RLS hardening.
--
-- 1) Enable FORCE ROW LEVEL SECURITY on every sensitive table so even the
--    owning role must honour policies (today tables are "owner-managed" and an
--    owning role could bypass the guidelines). In Supabase the tables are owned
--    by postgres/service which already bypass RLS via BYPASSRLS, so FORCE has
--    no functional cost for normal API traffic.
--
--    IMPORTANT compatibility note: owner-side reads still work because the
--    providers list is served through get_nearest_providers(...) which is
--    SECURITY DEFINER (runs as owner, policy-immune). The app's direct
--    provider writes are all self-scoped (eq('id', auth.uid())).
--
-- 2) Add the missing WITH CHECK to the generic ALL / UPDATE "own record"
--    policies so write paths cannot target rows outside auth.uid(). All other
--    tables already have per-command policies with correct USING/WITH CHECK.
--
-- No behavioural change: no column is restricted, no RPC output is altered.
-- =============================================================================

-- 1) FORCE ROW LEVEL SECURITY on all tables that hold person/market data.
alter table public.profiles              force row level security;
alter table public.providers             force row level security;
alter table public.orders                force row level security;
alter table public.notifications         force row level security;
alter table public.ratings               force row level security;
alter table public.car_details           force row level security;
alter table public.provider_car_details  force row level security;
alter table public.provider_specializations force row level security;
alter table public.order_event_secret    force row level security;

-- 2) Add WITH CHECK where the "own record" constraints were only enforced on read.

drop policy if exists "Users access own profile" on public.profiles;
create policy "Users access own profile"
  on public.profiles
  as permissive
  for all
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Provider manages own profile" on public.providers;
create policy "Provider manages own profile"
  on public.providers
  as permissive
  for all
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications"
  on public.notifications
  as permissive
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);