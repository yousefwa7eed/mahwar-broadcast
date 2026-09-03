-- =============================================================================
-- Reconstructed from the live DB (applied as migration "sync_profile_email_on_auth_email_change").
-- Syncs the auth.users email into public.profiles when an admin/user updates it,
-- via a trigger on auth.users. Previously emails updated in auth (e.g. update_user)
-- were not propagated to the public profile.
-- =============================================================================

-- Trigger function: on auth.users email change, mirror it to profiles.
create or replace function public.handle_user_email_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is distinct from old.email then
    update public.profiles
    set email = new.email,
        updated_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;

-- Trigger on auth.users AFTER UPDATE email
drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update on auth.users
  for each row
  execute function public.handle_user_email_update();
