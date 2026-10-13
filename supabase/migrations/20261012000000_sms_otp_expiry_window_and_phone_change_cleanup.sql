-- =============================================================================
-- Migration: SMS OTP expiry window for phone-change routing + stale cleanup
-- Date: 2026-10-12
--
-- Problem (send-sms-hook routing):
--   GoTrue serializes the in-progress phone change into the Send SMS hook
--   payload as user.new_phone (db auth.users.phone_change). The hook routed the
--   OTP to user.new_phone whenever it was non-empty, with no freshness check. If
--   a change was started and then abandoned, phone_change lingered on the row, so
--   a LATER sign-in / forgot-password OTP for the same account was delivered to
--   the abandoned (unverified, possibly recycled) number instead of user.phone.
--
-- Fix (this migration):
--   1. sms_cap_config.otp_expiry_seconds — the OTP validity window the hook uses
--      to decide whether an in-progress phone change is still "live". MUST equal
--      Supabase Auth -> Settings -> SMS OTP Expiry (GOTRUE_SMS_OTP_EXP). GoTrue
--      default is 60s; change BOTH this row and the Auth setting together.
--   2. clear_stale_phone_change() — service-role-only RPC the hook calls when it
--      sees an expired phone_change, so the stale value can never shadow a later
--      sign-in OTP again. Mirrors GoTrue's own defaults ('', '', null).
--
-- Security: the RPC is SECURITY DEFINER (needs auth.users write) and granted to
--   service_role only; anon/authenticated cannot call it.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. OTP expiry window (DB-authoritative; the edge function has no access to the
--    Auth service's in-memory config, so this row is its source of truth).
-- -----------------------------------------------------------------------------
insert into public.sms_cap_config (key, value, note) values
  ('otp_expiry_seconds', 60,
   'OTP valid window (seconds) the send-sms-hook uses to trust an in-progress phone change. MUST equal Auth -> Settings -> SMS OTP Expiry (GOTRUE_SMS_OTP_EXP). Change both together.')
on conflict (key) do nothing;

-- -----------------------------------------------------------------------------
-- 2. clear_stale_phone_change(): null out an EXPIRED phone-change only.
--    Safe against races: a fresh phone_change (phone_change_sent_at within the
--    window) is never touched, so an in-flight change cannot be wiped.
-- -----------------------------------------------------------------------------
create or replace function public.clear_stale_phone_change(
  p_user_id       uuid,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cleared integer;
begin
  if p_user_id is null then
    return false;
  end if;
  if p_window_seconds is null or p_window_seconds < 0 then
    p_window_seconds := 0;
  end if;

  update auth.users u
     set phone_change          = '',
         phone_change_token    = '',
         phone_change_sent_at  = null
   where u.id = p_user_id
     and coalesce(u.phone_change, '') <> ''
     and (
       u.phone_change_sent_at is null
       or u.phone_change_sent_at < now() - make_interval(secs => p_window_seconds)
     );

  get diagnostics v_cleared = row_count;
  return v_cleared > 0;
end;
$$;

comment on function public.clear_stale_phone_change(uuid, integer) is
  'Clears an expired auth.users phone change (phone_change/phone_change_token/phone_change_sent_at). service_role-only; called by send-sms-hook.';

revoke execute on function public.clear_stale_phone_change(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.clear_stale_phone_change(uuid, integer)
  to service_role;
