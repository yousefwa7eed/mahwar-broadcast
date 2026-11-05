-- applied to live as 20261105183456 (verified against supabase_migrations.schema_migrations)
-- ============================================================================
-- Re-hardening pass: restore server-side admin MFA, and stop
-- get_public_profile() from handing out owner phone numbers.
--
-- Threat model (both items verified against the live project before writing):
--
--   1) is_admin() had lost its `aal` clause. The original definition
--      (20261017000000_admins_is_admin_audit_log.sql:104-127) required BOTH an
--      `admins` row AND JWT aal == 'aal2'. Live kept only the membership test,
--      and the string 'aal2' survived solely inside assert_admin()'s exception
--      MESSAGE — which advertised a control that no longer existed.
--      Consequence: any aal1 session holding the admin uuid could call every
--      admin_* RPC straight over REST, bypassing the dashboard's client-side
--      TOTP gate.
--
--      Restoring it is safe and was checked first: the admin account has a
--      verified TOTP factor (auth.mfa_factors.status = 'verified'); the
--      dashboard only skips MFA in a local dev build
--      (admin-dashboard/src/main.ts:20, SKIP_MFA = import.meta.env.DEV &&
--      VITE_SKIP_MFA === 'true'); and admin_session_state() computes
--      is_admin_row / aal / mfa_enrolled inline instead of calling is_admin(),
--      so the TOTP challenge screen still renders for an aal1 admin session.
--      assert_admin() is the only remaining caller, and no edge function or RLS
--      policy touches is_admin().
--
--   2) get_public_profile() returned profiles.phone_number to any authenticated
--      caller sharing an order row with the target, with no status gate. That
--      breaks the Stage-B invariant: an owner's phone may reach a provider only
--      once the order is 'confirmed', and only through get_order_contact().
--      The column is dropped rather than gated, because nothing reads it: the
--      only two consumers in the repo use full_name exclusively
--      (lib/features/notifications/notification_detail_screen.dart:78 and
--      lib/features/provider_home/provider_home_screen.dart:276), the admin
--      dashboard never calls this RPC, no edge function calls it, and pg_depend
--      reports nothing depends on the function.
--
--      A return type cannot be changed by CREATE OR REPLACE, so the function is
--      dropped and recreated; DROP destroys grants, so the original ACL is
--      re-applied and anon stays ungranted.
--
-- Deliberately NOT changed: get_email_by_phone() keeps EXECUTE for anon.
-- Phone-based login resolves the identifier while the caller is still anon
-- (lib/core/auth/auth_service.dart:438, reached from the sign-in flow at
-- lib/core/auth/auth_cubit.dart:425), so revoking that grant would lock every
-- phone user out of the app. Its throttle is keyed on the *target* phone rather
-- than the caller, which is a genuine enumeration weakness, but closing it needs
-- an architectural change — resolving the email inside an authenticated or
-- OTP-verified context, or per-IP limiting at the proxy — not a grant flip.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) is_admin(): restore the aal2 requirement, verbatim from the original
--    migration, including the comment that documents the fail-closed contract.
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
         <> '00000000-0000-0000-0000-000000000000'::uuid
     and coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
     and exists (
       select 1
       from public.admins a
       where a.user_id = auth.uid()
     );
$$;

comment on function public.is_admin() is
  'True only for a listed admin whose current request passed TOTP (aal2). Fails closed.';

revoke all on function public.is_admin() from public;
revoke all on function public.is_admin() from anon;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_admin() to service_role;

-- ---------------------------------------------------------------------------
-- 2) get_public_profile(): drop the phone_number output column. Same access
--    rule otherwise, so full_name / role / avatar keep working for callers who
--    legitimately share an order.
-- ---------------------------------------------------------------------------
drop function if exists public.get_public_profile(uuid);

create or replace function public.get_public_profile(p_user_id uuid)
returns table(full_name text, role user_role, avatar_id text, avatar_url text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select
    pf.full_name,
    pf.role,
    pf.avatar_id,
    pf.avatar_url
  from public.profiles pf
  where pf.id = p_user_id
    and (
      auth.uid() = p_user_id
      or exists (
        select 1
        from public.orders o
        where (o.car_owner_id = p_user_id and o.provider_id = auth.uid())
           or (o.provider_id = p_user_id and o.car_owner_id = auth.uid())
      )
    );
end;
$$;

comment on function public.get_public_profile(uuid) is
  'Identity lookup for parties who share an order. Never returns phone_number: '
  'owner contact details are released only by get_order_contact() once the order is confirmed.';

revoke all on function public.get_public_profile(uuid) from public;
revoke all on function public.get_public_profile(uuid) from anon;
grant execute on function public.get_public_profile(uuid) to authenticated;
grant execute on function public.get_public_profile(uuid) to service_role;
