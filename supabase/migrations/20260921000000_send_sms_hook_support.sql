-- =============================================================================
-- Migration: Send SMS Hook support (ZADX OTP delivery).
-- Date: 2026-09-21
--
-- Backing store for the `send-sms-hook` edge function:
--   * sms_send_logs  — every OTP send attempt (otp stored HASHED, never plaintext)
--   * sms_cap_config — daily budget caps (per-phone / global), edited in the DB
--   * profiles.phone_verified_at — mirror of auth.users.phone_confirmed_at
--   * get_my_phone_verified()    — RPC the app uses to gate on phone verification
--
-- Security: both tables have RLS enabled with NO policies, so the public Data API
-- (anon / authenticated) cannot read or write them. Only the service_role key
-- (used by the edge function) and SECURITY DEFINER functions can touch them.
--
-- Cap counting counts ONLY rows with result = 'sent' (an SMS credit was actually
-- consumed at ZADX). 'rejected' / 'failed' / 'dryrun' rows are recorded for
-- forensics but do not consume budget. 'dryrun' rows are written while testing
-- with SMS_DRY_RUN=true so the wiring test never eats into real caps.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. sms_send_logs — append-only attempt log (RLS on, no policies)
-- -----------------------------------------------------------------------------
create table if not exists public.sms_send_logs (
  id          bigint generated always as identity primary key,
  phone_local text        not null,  -- normalized 01xxxxxxxxx form (app convention)
  phone_e164  text        not null,  -- +201xxxxxxxxx form actually sent to ZADX
  user_id     uuid        null references auth.users(id) on delete set null,
  otp_hash    text        not null,  -- sha256("<e164>:<otp>"); exact code is never stored
  result      text        not null default 'sent'
              check (result in ('sent', 'failed', 'rejected', 'dryrun')),
  error_code  text        null,
  created_at  timestamptz not null default now()
);

create index if not exists sms_send_logs_phone_day_idx
  on public.sms_send_logs (phone_local, created_at desc);

create index if not exists sms_send_logs_day_idx
  on public.sms_send_logs (created_at desc);

alter table public.sms_send_logs enable row level security;
revoke all on public.sms_send_logs from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. sms_cap_config — budget knobs (edit values in SQL editor, not in secrets)
-- -----------------------------------------------------------------------------
create table if not exists public.sms_cap_config (
  key   text primary key,
  value integer not null,
  note  text    not null default ''
);

insert into public.sms_cap_config (key, value, note) values
  ('per_phone_per_day', 3,  'Max OTP SMS per phone per day (result = ''sent'' only)'),
  ('global_per_day',    20, 'Max OTP SMS across all phones per day (result = ''sent'' only)')
on conflict (key) do nothing;

alter table public.sms_cap_config enable row level security;
revoke all on public.sms_cap_config from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. profiles.phone_verified_at — mirror of auth.users.phone_confirmed_at
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists phone_verified_at timestamptz;

comment on column public.profiles.phone_verified_at is
  'Mirror of auth.users.phone_confirmed_at, kept in sync by on_auth_user_phone_verified_updated.';

create or replace function public.sync_phone_verified_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
     set phone_verified_at = new.phone_confirmed_at
   where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_phone_verified_updated on auth.users;
create trigger on_auth_user_phone_verified_updated
  after insert or update of phone, phone_confirmed_at on auth.users
  for each row
  execute function public.sync_phone_verified_from_auth();

-- Backfill for existing users (idempotent; today all phones are unverified so
-- this is a no-op, but it keeps the mirror honest after manual phone edits).
update public.profiles p
   set phone_verified_at = u.phone_confirmed_at
  from auth.users u
 where u.id = p.id
   and p.phone_verified_at is distinct from u.phone_confirmed_at;

-- -----------------------------------------------------------------------------
-- 4. get_my_phone_verified() — app bootstrap gate (authenticated only)
-- -----------------------------------------------------------------------------
create or replace function public.get_my_phone_verified()
returns boolean
language sql
security definer
set search_path = ''
as $$
  select coalesce((
    select phone_confirmed_at is not null
      from auth.users
     where id = auth.uid()
  ), false)
$$;

revoke all on function public.get_my_phone_verified() from public, anon;
grant execute on function public.get_my_phone_verified() to authenticated;