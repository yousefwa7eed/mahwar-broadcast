-- =============================================================================
-- Migration: widen the OTP validity window 60s -> 300s
-- Date: 2026-10-14
--
-- Why: a 60-second window is too tight for the ZADX SMS round-trip plus the time
-- a user needs to read and type the code. Expired-before-entry OTPs are a major
-- cause of abandoned signups (the accounts purge_abandoned_unverified_accounts
-- then has to clean up). 300s gives users a realistic window to complete OTP.
--
-- CRITICAL — this value lives in TWO places and they MUST match:
--   * Auth -> Settings -> SMS OTP Expiry  (env GOTRUE_SMS_OTP_EXP)  <-- manual,
--     hosted dashboard only; controls how long a minted OTP actually verifies.
--   * sms_cap_config.otp_expiry_seconds   (this row)               <-- the window
--     send-sms-hook uses to trust an in-progress phone change
--     (user.new_phone fallback + clear_stale_phone_change window).
--
-- The unsafe direction is DB > GoTrue: if the hook trusts a phone change longer
-- than the OTP is actually valid, a later sign-in OTP can be routed to an
-- abandoned (possibly recycled) number — the exact bug migration
-- 20261012000000 fixed. So the dashboard MUST be set to 300 BEFORE this applies.
--
-- Ordering used: dashboard set to 300 by the operator, THEN this migration.
-- =============================================================================

insert into public.sms_cap_config (key, value, note)
values (
  'otp_expiry_seconds',
  300,
  'OTP valid window (seconds) the send-sms-hook uses to trust an in-progress phone change. MUST equal Auth -> Settings -> SMS OTP Expiry (GOTRUE_SMS_OTP_EXP). Change both together.'
)
on conflict (key) do update
  set value = excluded.value,
      note  = excluded.note;
