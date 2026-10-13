-- =============================================================================
-- Migration: enforce OTP for phone-number changes; mirror verified auth phone
-- Date: 2026-10-11
--
-- Problem:
--   edit_personal_info_screen.dart writes public.profiles.phone_number directly
--   via PostgREST with no OTP, while auth.users.phone (the number GoTrue can
--   actually verify and send OTP to) is never touched. profiles.phone_number is
--   the source for login-by-phone (get_email_by_phone) and order contact info,
--   so an unverified / attacker-chosen number becomes authoritative for login.
--
-- Fix (DB side):
--   1. canonical_phone()  — last 10 digits (national significant number), the
--      only common form between auth "20XXXXXXXXXX" and profiles "0XXXXXXXXXX".
--   2. BEFORE UPDATE OF phone_number guard on public.profiles: an app user may
--      only change phone_number to a value that canonical-equals their OWN
--      confirmed auth.users.phone. auth.uid() IS NULL (service_role, SQL editor,
--      migrations, admin tooling, and the GoTrue auth-context connection that
--      fires the sync trigger below) bypasses the guard.
--   3. AFTER UPDATE sync on auth.users: when phone_confirmed_at advances, write
--      profiles.phone_number in local 0XXXXXXXXXX form.
--
-- Unaffected: handle_new_user (signup INSERT; the guard is UPDATE-only),
--   delete-account (cleanup_user_data + admin DELETE), and any update that does
--   not touch phone_number — including old app builds that re-send the SAME
--   phone_number (canonical-equal -> allowed).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Canonical form: last 10 digits
-- -----------------------------------------------------------------------------
create or replace function public.canonical_phone(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(right(regexp_replace(coalesce(p, ''), '\D', '', 'g'), 10), '');
$$;

comment on function public.canonical_phone(text) is
  'Last 10 digits of a phone number (national significant number). Common form between auth.users.phone (20XXXXXXXXXX) and profiles.phone_number (0XXXXXXXXXX).';

-- -----------------------------------------------------------------------------
-- 2. Guard: phone_number may change only to the caller's OWN confirmed auth phone
-- -----------------------------------------------------------------------------
create or replace function public.guard_profile_phone_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_confirmed text;
begin
  -- Non-app contexts (service_role, SQL editor, migrations, admin tooling, and
  -- the GoTrue connection that fires the sync trigger) have no JWT subject.
  if auth.uid() is null then
    return new;
  end if;

  -- Clearing the phone, or a change that is numerically the same, is allowed.
  if new.phone_number is null
     or public.canonical_phone(new.phone_number)
        is not distinct from public.canonical_phone(old.phone_number) then
    return new;
  end if;

  -- A real change must match THIS user's confirmed auth phone.
  select public.canonical_phone(u.phone)
    into v_confirmed
    from auth.users u
   where u.id = new.id
     and u.phone_confirmed_at is not null;

  if v_confirmed is null
     or v_confirmed <> public.canonical_phone(new.phone_number) then
    raise exception 'PHONE_CHANGE_REQUIRES_OTP';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_phone_requires_verified on public.profiles;
create trigger profiles_phone_requires_verified
  before update of phone_number on public.profiles
  for each row
  execute function public.guard_profile_phone_change();

-- -----------------------------------------------------------------------------
-- 3. Sync: verified auth phone -> profiles.phone_number (local form)
-- -----------------------------------------------------------------------------
create or replace function public.sync_phone_number_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.phone is not null
     and new.phone_confirmed_at is not null then
    update public.profiles
       set phone_number = '0' || right(regexp_replace(new.phone, '\D', '', 'g'), 10)
     where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_phone_number_synced on auth.users;
create trigger on_auth_user_phone_number_synced
  after update of phone, phone_confirmed_at on auth.users
  for each row
  when (new.phone_confirmed_at is distinct from old.phone_confirmed_at)
  execute function public.sync_phone_number_from_auth();

-- -----------------------------------------------------------------------------
-- 4. Trigger-only functions: no direct EXECUTE for API roles.
--    canonical_phone is used only by the two functions above; the client does
--    NOT need it (the pre-send duplicate check reuses get_email_by_phone).
-- -----------------------------------------------------------------------------
revoke execute on function public.canonical_phone(text) from public, anon, authenticated;
revoke execute on function public.guard_profile_phone_change() from public, anon, authenticated;
revoke execute on function public.sync_phone_number_from_auth() from public, anon, authenticated;
