-- =============================================================================
-- Sync profiles.role -> auth.users.raw_user_meta_data['role'] on change.
--
-- Rationale: auth metadata (embedded in the JWT at sign-in and used for
-- home-screen routing / FCM topic) can drift when an admin edits
-- profiles.role directly (dashboard / SQL / service-role), because today the
-- copy metadata->profiles happens only once at sign-up (handle_new_user) and
-- no trigger propagates the reverse direction.
--
-- This trigger closes that gap: any role change on public.profiles is merged
-- into raw_user_meta_data (key-wise merge, other keys preserved), so the next
-- sign-in mints a token that already carries the correct role.
--
-- Behaviour:
--   * Fires ONLY when role actually changed        (WHEN ... IS DISTINCT FROM)
--   * Merges a single key; never replaces metadata  (jsonb || jsonb_build_object)
--   * No loop: it writes auth.users.raw_user_meta_data only; the existing
--     on_auth_user_email_updated trigger on auth.users is guarded by an email
--     change, which we never touch -> no write-back to profiles, no recursion.
-- =============================================================================

create or replace function public.sync_auth_role_from_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update auth.users
  set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
                           || jsonb_build_object('role', new.role)
  where id = new.id
    and coalesce(raw_user_meta_data ->> 'role', '') is distinct from new.role::text;
  return new;
end;
$$;

drop trigger if exists on_profile_role_updated on public.profiles;
create trigger on_profile_role_updated
  after update on public.profiles
  for each row
  when (new.role is distinct from old.role)
  execute function public.sync_auth_role_from_profile();

-- =============================================================================
-- OPTIONAL backfill: the trigger fixes FUTURE changes only. Run the block below
-- once if any existing profiles already diverge from their auth metadata
-- (idempotent: only touches rows where metadata['role'] differs/missing).
-- =============================================================================
-- update auth.users u
-- set raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb)
--                          || jsonb_build_object('role', p.role)
-- from public.profiles p
-- where p.id = u.id
--   and coalesce(u.raw_user_meta_data ->> 'role', '') is distinct from p.role::text;