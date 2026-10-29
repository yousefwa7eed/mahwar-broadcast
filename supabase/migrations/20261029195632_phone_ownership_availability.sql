-- =============================================================================
-- Migration: canonical phone ownership — availability RPC, auth-only signup
--            guard, and clearing the profile mirror when auth.phone is removed
-- Date: 2026-10-29
-- applied as 20261029195632
--
-- Invariant enforced from here on:
--   auth.users.phone             = the canonical, OTP-verified number (GoTrue).
--   public.profiles.phone_number = a MIRROR, written only by
--                                  sync_phone_number_from_auth after the auth
--                                  phone is confirmed (never by the client;
--                                  see 20261011000000_guard_verified_phone_change).
--
-- Problem being closed (Batch 1 of the phone-ownership fix):
--   The change-number pre-check and the signup guard both look only at
--   public.profiles, while GoTrue enforces auth.users.phone (users_phone_key).
--   A number can therefore be owned in auth without any profile holding it
--   (admin-created / profile-less accounts), so:
--     * the app claims a number is free, sends an SMS, then GoTrue rejects the
--       attach with 422 phone_exists (wasted SMS, confusing UI);
--     * a second signup can pick a number that is already an auth login.
--
-- What this migration adds:
--   1. public.phone_in_use()     — one canonical answer to "is this number
--      owned?", checking auth.users.phone, a *fresh* auth.users.phone_change
--      (pending OTP of another account) and profiles.phone_number.
--   2. public.is_phone_available() — authenticated-only RPC with the same
--      5/hour/phone throttle as get_email_by_phone (shared attempt table).
--   3. enforce_signup_phone_unique() — BEFORE INSERT on auth.users so a signup
--      whose metadata phone is held only in auth.users gets
--      ACCOUNT_EXISTS_AS:unknown (neutral, no role leak). The profiles case is
--      deliberately left to handle_new_user so its role-specific
--      ACCOUNT_EXISTS_AS:<role> message is unchanged.
--   4. F10 — when GoTrue nulls auth.users.phone, the profile mirror
--      (phone_number + phone_verified_at) is cleared instead of keeping a
--      stale, login-bearing number forever.
--
-- Deliberate non-goals: get_email_by_phone is untouched (login keeps reading
-- profiles only — a fallback there would expose admin emails), no old-number
-- OTP, no synthetic-email rotation.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Canonical ownership check (internal; no direct API access)
-- -----------------------------------------------------------------------------
-- Every accepted input form is folded to the 11-digit local form
-- ('0' || last 10 digits) because auth.users.phone is '20XXXXXXXXXX' while
-- profiles.phone_number is '01XXXXXXXXX'. normalize_phone() does NOT convert
-- a bare '20…' value, so canonical_phone() is what makes the two comparable.
create or replace function public.phone_in_use(
  p_phone text,
  p_exclude_user uuid default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_canon  text;
  v_window int;
begin
  v_canon := '0' || public.canonical_phone(public.normalize_phone(p_phone));
  if v_canon is null then
    raise exception 'INVALID_PHONE';
  end if;

  -- A pending phone_change is only meaningful while its OTP can still be
  -- verified; after that GoTrue has either promoted it to phone or dropped it.
  v_window := coalesce(
    (select c.value from public.sms_cap_config c where c.key = 'otp_expiry_seconds'),
    300
  );

  -- (a) Confirmed phone of any other account.
  if exists (
    select 1
    from auth.users u
    where u.id is distinct from p_exclude_user
      and '0' || public.canonical_phone(public.normalize_phone(u.phone)) = v_canon
  ) then
    return true;
  end if;

  -- (b) In-flight phone change of any other account (OTP still valid).
  if exists (
    select 1
    from auth.users u
    where u.id is distinct from p_exclude_user
      and u.phone_change is not null
      and u.phone_change <> ''
      and u.phone_change_sent_at > now() - make_interval(secs => v_window)
      and '0' || public.canonical_phone(public.normalize_phone(u.phone_change)) = v_canon
  ) then
    return true;
  end if;

  -- (c) Profile mirror (covers rows whose auth phone was never promoted).
  if exists (
    select 1
    from public.profiles p
    where p.id is distinct from p_exclude_user
      and '0' || public.canonical_phone(public.normalize_phone(p.phone_number)) = v_canon
  ) then
    return true;
  end if;

  return false;
end;
$function$;

comment on function public.phone_in_use(text, uuid) is
  'True when the number is owned by another account in auth.users.phone, a fresh auth.users.phone_change, or profiles.phone_number. Internal only: EXECUTE is revoked from API roles.';

-- -----------------------------------------------------------------------------
-- 2. is_phone_available — authenticated client pre-check for the change-number
-- -----------------------------------------------------------------------------
-- Returns TRUE when the number is free for the caller (their own number counts
-- as free, so re-entering the current number never blocks).
-- Reuses public.email_lookup_attempts: 5 lookups per phone per rolling hour,
-- purged after 1 day. Same budget as get_email_by_phone for local-form inputs.
create or replace function public.is_phone_available(p_phone text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid     uuid := auth.uid();
  v_digits  text;
  v_recent  int;
  v_limit   int := 5;  -- lookups per phone per rolling hour
  v_attempt bigint;
  v_taken   boolean;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- Reject null/garbage explicitly instead of silently canonicalising it.
  if p_phone is null
     or btrim(p_phone) = ''
     or p_phone !~ '^[+0-9٠-٩۰-۹ ()\-]+$' then
    raise exception 'INVALID_PHONE';
  end if;

  -- Fold Arabic-Indic digits BEFORE stripping, then reduce every accepted
  -- representation (+20…, 20…, 0020…, 0…) to the 11-digit local form.
  v_digits := regexp_replace(public.fold_phone_digits(p_phone), '\D', '', 'g');
  if v_digits ~ '^0020[0-9]{10}$' then
    v_digits := '0' || substr(v_digits, 5);
  elsif v_digits ~ '^20[0-9]{10}$' then
    v_digits := '0' || substr(v_digits, 3);
  end if;

  if v_digits !~ '^01[0125][0-9]{8}$' then
    raise exception 'INVALID_PHONE';
  end if;

  delete from public.email_lookup_attempts
   where attempted_at < now() - interval '1 day';

  select count(*)
    into v_recent
  from public.email_lookup_attempts
  where phone = v_digits
    and attempted_at > now() - interval '1 hour';

  if v_recent >= v_limit then
    raise exception 'TOO_MANY_LOOKUPS';
  end if;

  insert into public.email_lookup_attempts (phone)
  values (v_digits)
  returning id into v_attempt;

  v_taken := public.phone_in_use(v_digits, v_uid);

  -- found = "owned by someone else"; keeps the audit column meaningful.
  update public.email_lookup_attempts
     set found = v_taken
   where id = v_attempt;

  return not v_taken;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 3. Signup guard: a number held only in auth.users must also be taken
-- -----------------------------------------------------------------------------
-- Why a separate BEFORE INSERT trigger instead of editing handle_new_user:
-- the live handle_new_user body has drifted from the committed migration
-- (live body 6209 non-space chars vs 8111 in 20261027153726_vehicles_cutover),
-- so a full CREATE OR REPLACE built from the repo file would risk reverting
-- live fixes that were never filed. This trigger adds exactly one check and
-- leaves handle_new_user byte-for-byte untouched.
--
-- Error precedence is preserved: when profiles already holds the number this
-- trigger returns early and handle_new_user raises the role-specific
-- ACCOUNT_EXISTS_AS:<role>. Only the auth-only case raises the neutral
-- ACCOUNT_EXISTS_AS:unknown (already mapped to signupAccountExistsUnknown).
create or replace function public.enforce_signup_phone_unique()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_phone text;
begin
  if new.raw_user_meta_data ->> 'signup_source' = 'admin_dashboard' then
    return new;
  end if;

  v_phone := public.normalize_phone(new.raw_user_meta_data ->> 'phone_number');
  if v_phone is null or btrim(v_phone) = '' then
    return new;
  end if;

  -- Profiles case -> let handle_new_user speak (role-specific message).
  if exists (
    select 1
    from public.profiles p
    where '0' || public.canonical_phone(public.normalize_phone(p.phone_number))
          = '0' || public.canonical_phone(v_phone)
  ) then
    return new;
  end if;

  -- Auth-only case -> neutral "exists in another account", no role leak.
  if public.phone_in_use(v_phone, new.id) then
    raise exception 'ACCOUNT_EXISTS_AS:unknown';
  end if;

  return new;
end;
$function$;

drop trigger if exists enforce_signup_phone_unique on auth.users;
create trigger enforce_signup_phone_unique
  before insert on auth.users
  for each row
  execute function public.enforce_signup_phone_unique();

-- -----------------------------------------------------------------------------
-- 4. F10 — removing the auth phone must clear the profile mirror
-- -----------------------------------------------------------------------------
-- public.profiles.phone_number is currently NOT NULL in the live schema, but
-- three states are legitimate: signups may later be phone-less, and a cleared
-- auth phone must not leave a login-bearing mirror behind. The CHECK
-- (phone_number IS NULL OR ^01[0125][0-9]{8}$) already allows NULL.
alter table public.profiles
  alter column phone_number drop not null;

create or replace function public.sync_phone_number_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  -- F10: the verified number is gone -> drop the mirror too, so a stale number
  -- can no longer be used for login-by-phone (get_email_by_phone) or order
  -- contact info. The profile guard allows this because auth.uid() is null on
  -- the GoTrue connection (see 20261011000000_guard_verified_phone_change).
  if new.phone is null then
    if old.phone is not null then
      update public.profiles
         set phone_number = null,
             phone_verified_at = null
       where id = new.id;
    end if;
    return new;
  end if;

  if new.phone_confirmed_at is not null then
    update public.profiles
       set phone_number = '0' || right(regexp_replace(new.phone, '\D', '', 'g'), 10)
     where id = new.id;
  end if;
  return new;
end;
$function$;

-- Broadened WHEN: nulling phone (or un-confirming it) must reach the function
-- even when phone_confirmed_at happens to change in the same statement.
drop trigger if exists on_auth_user_phone_number_synced on auth.users;
create trigger on_auth_user_phone_number_synced
  after update of phone, phone_confirmed_at on auth.users
  for each row
  when (new.phone is distinct from old.phone
        or new.phone_confirmed_at is distinct from old.phone_confirmed_at)
  execute function public.sync_phone_number_from_auth();

-- Companion trigger (20260921000000_send_sms_hook_support.sql) rewrites
-- phone_verified_at unconditionally. On an AFTER trigger, it fires *after*
-- sync_phone_number_from_auth (alphabetical order), so without this change it
-- would immediately re-set phone_verified_at to the old confirmation time and
-- undo F10. Null the timestamp whenever the auth phone is gone.
create or replace function public.sync_phone_verified_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update public.profiles
     set phone_verified_at = case
           when new.phone is null then null
           else new.phone_confirmed_at
         end
   where id = new.id;
  return new;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 5. Privileges
-- -----------------------------------------------------------------------------
-- Trigger/internal helpers: no API access at all.
revoke all on function public.phone_in_use(text, uuid) from public, anon, authenticated;
revoke all on function public.enforce_signup_phone_unique() from public, anon, authenticated;
revoke all on function public.sync_phone_number_from_auth() from public, anon, authenticated;
revoke all on function public.sync_phone_verified_from_auth() from public, anon, authenticated;

-- Client pre-check: signed-in users only (the change-number flow always has a
-- session; an anon caller gets a plain "permission denied for function").
revoke all on function public.is_phone_available(text) from public, anon, authenticated;
grant execute on function public.is_phone_available(text) to authenticated;
