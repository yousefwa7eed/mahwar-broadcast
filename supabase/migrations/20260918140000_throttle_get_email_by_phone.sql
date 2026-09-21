-- Migration: throttle get_email_by_phone (H5, product-approved approach).
-- Date: 2026-09-18
--
-- The app resolves a phone number to an email during SIGN-IN, pre-auth
-- (lib/core/auth/auth_cubit.dart:213-216), so `get_email_by_phone` must stay
-- anon-EXECUTE. To stop phone->email bulk mapping (phishing/ATO), throttle
-- per phone number:
--   - max 5 lookups per phone per rolling hour  (RATE_LIMIT_PER_HOUR)
--   - attempts purged after 1 day
-- The throttle table is server-side and only touched by this SECURITY
-- DEFINER function (RLS off); anonymous users cannot tamper with counters.
--
-- Behavior is otherwise unchanged from the pre-fix function (same normalization,
-- same profiles lookup, same return contract), so the Flutter client needs no edit.

create table if not exists public.email_lookup_attempts (
  id          bigint generated always as identity primary key,
  phone       text not null,
  attempted_at timestamptz not null default now(),
  found       boolean not null default false
);

create index if not exists email_lookup_attempts_phone_time_idx
  on public.email_lookup_attempts (phone, attempted_at desc);

create or replace function public.get_email_by_phone(p_phone text)
 returns text
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_clean  text;
  v_email  text;
  v_recent int;
  v_limit  int := 5;  -- lookups per phone per rolling hour
begin
  v_clean := public.normalize_phone(p_phone);
  if v_clean is null or v_clean = '' then
    raise exception 'INVALID_PHONE';
  end if;

  -- opportunistic purge of stale attempts
  delete from public.email_lookup_attempts
   where attempted_at < now() - interval '1 day';

  select count(*)
    into v_recent
  from public.email_lookup_attempts
  where phone = v_clean
    and attempted_at > now() - interval '1 hour';

  if v_recent >= v_limit then
    raise exception 'TOO_MANY_LOOKUPS';
  end if;

  insert into public.email_lookup_attempts (phone)
  values (v_clean)
  returning id into v_recent;  -- reuse v_recent as scratch for row id

  select email into v_email
  from public.profiles
  where phone_number = v_clean
     or public.normalize_phone(phone_number) = v_clean
  limit 1;

  if v_email is not null then
    update public.email_lookup_attempts
       set found = true
     where id = v_recent;
  end if;

  return v_email;
end;
$function$;