-- Migration: remove broad providers ALL policy (M2, follow-up).
-- Date: 2026-09-18
--
-- The permissive `Provider manages own profile` policy is FOR ALL with
-- `WITH CHECK auth.uid() = id`. Because policies are OR-combined, it re-granted
-- self-INSERT and defeated the role-gated INSERT policy added in
-- 20260918150000 (a car_owner could still self-inscribe as a provider).
--
-- The discrete policies already cover the needed operations:
--   SELECT -> "Users can read own provider profile"   (auth.uid() = id)
--   UPDATE -> "Users can update own provider profile" (auth.uid() = id)
--   INSERT -> "Users can insert own provider profile" (role-gated)
-- DELETE is not used by the app; provider rows are removed by the
-- profiles -> providers ON DELETE CASCADE when the account is deleted
-- (service_role path). So the broad ALL policy is pure attack surface.

drop policy if exists "Provider manages own profile" on public.providers;