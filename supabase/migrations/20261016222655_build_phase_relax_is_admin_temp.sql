-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20261016222655 | name: build_phase_relax_is_admin_temp
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- HISTORY: this relaxation was later reverted by
--          20261105183456_reharden_admin_aal2_and_strip_public_profile_phone.sql
--          (is_admin() again requires auth.jwt() ->> 'aal' = 'aal2').
-- =============================================================================
-- =============================================================================
-- TEMPORARY BUILD-PHASE RELAXATION (delete this migration in re-hardening):
-- During the dashboard build phase only, is_admin() requires ONLY the admins
-- row. The aal2 (TOTP) requirement is SUSPENDED so testing does not hinge on
-- the MFA enrollment flow still under construction.
-- MUST be turned back on by 20261017020099_restore_admin_security.sql after
-- the dashboard is complete and yousef has enrolled TOTP on two devices.
-- =============================================================================
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

comment on function public.is_admin() is
  'BUILD-PHASE(TMP): admins row only. aal2 is suspended - MUST be restored before production use.';

revoke all on function public.is_admin() from public;
revoke all on function public.is_admin() from anon;
grant execute on function public.is_admin() to authenticated, service_role;
