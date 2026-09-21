-- =============================================================================
-- Role is immutable after signup.
--
-- car_owner / provider is fixed at account creation and there is NO supported
-- "customer becomes provider later" flow in this app. Role changes after
-- creation are never legitimate.
--
-- Vulnerability closed by this migration:
--   The profiles RLS policy "Users can update own profile" allows any
--   authenticated user to flip profiles.role between car_owner and provider via
--   a direct API call, bypassing the UI entirely. The AFTER UPDATE trigger
--   sync_auth_role_from_profile (20260913000001) then propagates that flip into
--   auth.users.raw_user_meta_data, so it takes effect on the next JWT — letting
--   a customer self-promote to provider and appear in the available-providers
--   list.
--
-- Why a BEFORE UPDATE trigger and not an RLS WITH CHECK:
--   RLS WITH CHECK expressions only see the NEW row; they cannot compare
--   NEW.role to OLD.role, so "role may not change" is not expressible as a
--   policy. A BEFORE UPDATE trigger is the correct enforcement point.
--
-- Caller policy:
--   * app users / anon (JWT, request.jwt.claims) -> role frozen from signup
--   * service_role (admin tooling)              -> allowed
--   * internal / postgres direct access         -> allowed
--
-- No legitimate internal process currently updates profiles.role:
--   - Flutter writes only full_name / phone_number / email / national_id /
--     fcm_token / avatar_id (edit_personal_info_screen, auth_cubit, avatar).
--   - Edge functions only read role (send-push-notification topic routing).
--   - The only DB-side writer is handle_new_user at signup (INSERT), plus the
--     reverse sync trigger fired by role changes (now app-user-unreachable).
-- =============================================================================

create or replace function public.guard_role_immutable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role
     and coalesce(auth.role(), '') not in ('service_role', '') then
    raise exception
      'ROLE_IMMUTABLE: role cannot be changed after signup (% -> %)',
      old.role,
      new.role;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_role_immutable on public.profiles;
create trigger profiles_role_immutable
  before update on public.profiles
  for each row
  execute function public.guard_role_immutable();

-- =============================================================================
-- NOTE: sync_auth_role_from_profile (20260913000001_sync_meta_role_on_profile_change)
-- is now effectively dead for app-user flows, because role can no longer change
-- for them. It is intentionally KEPT so that the one remaining legitimate path —
-- a service-role / admin role flip — still propagates into auth metadata (and
-- thus the next JWT). Do not remove without an explicit decision.
-- =============================================================================