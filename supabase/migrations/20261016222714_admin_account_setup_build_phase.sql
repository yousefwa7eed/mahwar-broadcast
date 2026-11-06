-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20261016222714 | name: admin_account_setup_build_phase
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
--
-- !! SECURITY — VALUE REDACTED !!
-- The live statement sets a literal temporary build-phase password through
-- crypt('<value>', gen_salt('bf', 10)). That literal is deliberately NOT
-- committed here, per the project rule that secrets never enter the repo.
-- Recover it from the live statements array only if this migration must be
-- replayed, and rotate that account's password afterwards.
-- =============================================================================
-- =============================================================================
-- Admin control account setup (build phase):
-- Target: 13c74053-6bb4-4e8b-9e3a-d42028dae083 (yousefwaheedgad@gmail.com)
-- That account was created 2026-10-15 as a normal app car_owner signup. To use
-- it as the dashboard's auth-only admin it must:
--   1) lose its app profile + car rows (out of the app entirely, as agreed)
--   2) join public.admins
--   3) be pinned against the abandoned-signup purge
--   4) get a fresh build-phase password (temporary; reset at re-hardening)
-- =============================================================================
do $$
declare
  v_admin uuid := '13c74053-6bb4-4e8b-9e3a-d42028dae083';
begin
  delete from public.profiles where id = v_admin;
  delete from public.car_details where user_id = v_admin;

  insert into public.admins (user_id, note)
  values (v_admin, 'owner admin (build phase setup)')
  on conflict (user_id) do nothing;

  insert into public.unverified_account_exemptions (user_id, reason)
  values (v_admin, 'admin dashboard control account (converted from car_owner signup)')
  on conflict (user_id) do update set reason = excluded.reason;
end;
$$;

-- Temporary build-phase password (MUST be reset at re-hardening).
-- The literal value is redacted in this repo copy — see the header note above.
update auth.users
set encrypted_password = crypt('<REDACTED_BUILD_PHASE_PASSWORD>', gen_salt('bf', 10)),
    updated_at = now()
where id = '13c74053-6bb4-4e8b-9e3a-d42028dae083';
