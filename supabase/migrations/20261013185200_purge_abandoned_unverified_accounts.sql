-- =============================================================================
-- Migration: purge abandoned unverified signups (daily cron)
-- Date: 2026-10-14
--
-- Why:
--   Signup creates a full account (profiles + providers/car_details) immediately
--   because the generated email is auto-confirmed, but the phone is NOT verified
--   until the user completes the OTP flow. Accounts abandoned mid-signup linger
--   forever: they pollute dispatch (an unverified provider could still appear
--   near-online), consume phone-change/SMS bookkeeping, and never belong to a
--   real, reachable user. Task 1 gates these accounts server-side and client-side;
--   this migration is the garbage collector that finally removes the dead rows.
--
-- Safety model (a destructive job must be conservative):
--   1. purge_only_after  — the instant this migration is applied. Accounts that
--      already existed before the gate shipped are NEVER purged, so no
--      long-standing account is deleted abruptly. (Only accounts created after
--      the feature is live are candidates.)
--   2. grace               — 24h. A user has a full day to finish OTP before the
--      account is considered abandoned.
--   3. no orders           — anyone with any order (as owner OR provider) is kept
--      forever; order history is never destroyed.
--   4. exemptions          — explicit allow-list to pin any account out of the
--      purge (tests, staff, manual rescues).
--   5. enabled             — a single kill-switch row. Set enabled = false in the
--      DB to stop the job without touching code or cron.
--
-- Deletion path: reuse public.cleanup_user_data(uuid) (removes notifications,
--   provider rows, car_details, profiles), then DELETE FROM auth.users. This
--   mirrors the established account-deletion path. For an account with no orders
--   the orders delete inside cleanup_user_data is a no-op.
--
-- Scheduled via pg_cron (in-database SQL, same pattern as expire_overdue_orders
-- and cleanup_stale_broadcast_images — the edge-function pipeline proved
-- unreliable in production). Runs daily at 03:30 UTC.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Config (single row) — grace window, hard cutoff, kill switch.
-- -----------------------------------------------------------------------------
create table if not exists public.abandoned_signup_purge_config (
  singleton        boolean     primary key default true check (singleton),
  enabled          boolean     not null default true,
  grace            interval    not null default interval '24 hours',
  -- Never purge accounts created at or before this instant (protects everything
  -- that existed before the gate shipped). Defaults to migration time.
  purge_only_after timestamptz not null default now()
);

insert into public.abandoned_signup_purge_config (singleton)
values (true)
on conflict (singleton) do nothing;

alter table public.abandoned_signup_purge_config enable row level security;
revoke all on public.abandoned_signup_purge_config from anon, authenticated;

comment on table public.abandoned_signup_purge_config is
  'Knobs for purge_abandoned_unverified_accounts(): enabled, grace, and the hard purge_only_after cutoff. service_role / cron only.';

-- -----------------------------------------------------------------------------
-- 2. Exemptions — explicit allow-list of never-purge accounts.
-- -----------------------------------------------------------------------------
create table if not exists public.unverified_account_exemptions (
  user_id    uuid primary key,
  reason     text not null default '',
  created_at timestamptz not null default now()
);

alter table public.unverified_account_exemptions enable row level security;
revoke all on public.unverified_account_exemptions from anon, authenticated;

comment on table public.unverified_account_exemptions is
  'Accounts pinned out of the abandoned-signup purge (tests, staff, manual rescues). Insert user_id rows to protect an account.';

-- -----------------------------------------------------------------------------
-- 3. The purge job.
-- -----------------------------------------------------------------------------
create or replace function public.purge_abandoned_unverified_accounts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enabled    boolean;
  v_grace      interval;
  v_only_after timestamptz;
  v_ids        uuid[];
  v_id         uuid;
  v_count      integer := 0;
begin
  select enabled, grace, purge_only_after
    into v_enabled, v_grace, v_only_after
    from public.abandoned_signup_purge_config
   where singleton;

  -- Kill switch / misconfiguration => do nothing.
  if not coalesce(v_enabled, false) or v_grace is null or v_only_after is null then
    return 0;
  end if;

  select array_agg(u.id)
    into v_ids
    from auth.users u
   where u.phone_confirmed_at is null
     and u.created_at > v_only_after
     and u.created_at < now() - v_grace
     and not exists (
       select 1 from public.unverified_account_exemptions e where e.user_id = u.id
     )
     and not exists (
       select 1 from public.orders o
        where o.car_owner_id = u.id or o.provider_id = u.id
     );

  if v_ids is null then
    return 0;
  end if;

  foreach v_id in array v_ids loop
    perform public.cleanup_user_data(v_id);
    delete from auth.users where id = v_id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

comment on function public.purge_abandoned_unverified_accounts() is
  'Deletes abandoned unverified signups (auth.users.phone_confirmed_at IS NULL) older than grace, created after purge_only_after, without orders, not exempted. Cron-only.';

-- Cron-only function: not callable by clients.
revoke execute on function public.purge_abandoned_unverified_accounts()
  from public, anon, authenticated;
grant execute on function public.purge_abandoned_unverified_accounts()
  to service_role;

-- -----------------------------------------------------------------------------
-- 4. Schedule it daily (03:30 UTC).
-- -----------------------------------------------------------------------------
select cron.schedule('purge-abandoned-unverified-accounts', '30 3 * * *',
                     'select public.purge_abandoned_unverified_accounts();');
