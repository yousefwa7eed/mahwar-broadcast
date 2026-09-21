-- Migration: Revoke anonymous access to public_provider_profiles.
-- Date: 2026-09-18
--
-- public_provider_profiles is a postgres-owned view used as the provider
-- directory projection (read by get_nearest_providers / get_provider_details).
-- Because it is not security_invoker, it intentionally bypasses the own-row-only
-- RLS on providers/profiles; that is required for the directory to work.
--
-- The defect was that it was SELECT-able by the `anon` role, exposing every
-- provider's name, phone, address and coordinates to unauthenticated callers.
-- The app has no guest mode and every provider-browsing screen is behind login,
-- so anon access is removed here. Authenticated access is retained.
--
-- NOTE: a security_invoker=true switch is NOT used because the underlying
-- providers/profiles RLS is own-row-only and would hide every other provider.

REVOKE ALL ON public.public_provider_profiles FROM anon;
REVOKE ALL ON public.public_provider_profiles FROM PUBLIC;
GRANT SELECT ON public.public_provider_profiles TO authenticated;
