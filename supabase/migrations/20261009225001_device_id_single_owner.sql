-- =============================================================================
-- profiles.device_id — one account per physical install.
--
-- Root cause: fcm_token is a per-install value, but nothing ties one device to
-- one account. If two accounts log in on the same install, both profiles end
-- up with the same device's token, so the last login silently hijacks push
-- notifications meant for the other account.
--
-- Fix:
--   1. profiles.device_id text (NULL): a UUID generated once per install and
--      persisted in secure storage. The app writes it together with fcm_token
--      on login and on token refresh.
--   2. AFTER UPDATE trigger (SECURITY DEFINER): whenever fcm_token or device_id
--      is written non-NULL, the writing row claims exclusive ownership of that
--      device/token by NULLing fcm_token AND device_id on every OTHER profile
--      that shares the same device_id OR the same fcm_token. The row that just
--      logged in keeps its own token.
--
-- SECURITY DEFINER / AFTER: RLS only lets a user update their own profiles row,
-- so a plain client UPDATE can never touch another account's row. The definer
-- trigger runs as the table owner and can reclaim the rival row in the same
-- statement that claims the device.
--
-- No recursion:
--   * Fires only when a non-NULL fcm_token/device_id is written
--     (WHEN new.fcm_token IS NOT NULL OR new.device_id IS NOT NULL).
--   * The cleanup UPDATE sets both columns to NULL, so the WHEN clause is false
--     for every nulled row — those rows don't re-fire, and a logout/login
--     sequence cannot ping-pong. One cleanup statement, one firing.
-- =============================================================================

alter table public.profiles
  add column if not exists device_id text;

create index if not exists profiles_device_id_idx
  on public.profiles (device_id)
  where device_id is not null;

create index if not exists profiles_fcm_token_idx
  on public.profiles (fcm_token)
  where fcm_token is not null;

create or replace function public.single_device_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set fcm_token = null,
      device_id = null
  where id is distinct from new.id
    and (
      (new.device_id is not null and device_id = new.device_id)
      or (new.fcm_token is not null and fcm_token = new.fcm_token)
    );
  return new;
end;
$$;

drop trigger if exists profiles_single_device_owner on public.profiles;
create trigger profiles_single_device_owner
  after insert or update of fcm_token, device_id on public.profiles
  for each row
  when (new.fcm_token is not null or new.device_id is not null)
  execute function public.single_device_owner();

-- Trigger-only function: no app role may call it directly (PostgREST RPC).
revoke execute on function public.single_device_owner()
  from public, anon, authenticated;