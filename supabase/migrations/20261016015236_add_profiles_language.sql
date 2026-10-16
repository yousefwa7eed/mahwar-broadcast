-- Migration: add profiles.language for bilingual notifications (design A).
--
-- The app already persists the language choice locally (SharedPreferences key
-- 'app_locale', AppSettingsCubit). This column mirrors it server-side so the
-- send-push-notification edge function can build push text in the recipient's
-- language instead of always Arabic.
--
-- 'ar' default preserves current behavior for every existing row (all are Arabic).
--
-- Access review (verified against the live project):
--   * RLS: policy "Users can update own profile" (UPDATE, roles public,
--     qual auth.uid() = id) plus "Users access own profile" (ALL, authenticated,
--     qual + with_check auth.uid() = id) → a user may UPDATE only their own row.
--   * No column-level grant restricts profiles (table-level UPDATE is granted to
--     authenticated); the new column is covered by the same table grant.
--   * Guard triggers do NOT block a language-only change:
--       - guard_role_immutable     (BEFORE UPDATE) raises only if role changed.
--       - guard_profile_phone_change (BEFORE UPDATE OF phone_number) not fired.
--       - single_device_owner       (AFTER INSERT OR UPDATE OF fcm_token, device_id) not fired.
--       - update_updated_at_column  (BEFORE UPDATE) just bumps updated_at.
--
-- No other DB change. handle_new_user needs no change: the column has a default.

alter table public.profiles
  add column if not exists language text not null default 'ar';

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conname = 'profiles_language_check'
       and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_language_check check (language in ('ar', 'en'));
  end if;
end $$;

comment on column public.profiles.language is
  'User preferred language for UI and push text: ''ar'' or ''en''. Mirrors the app locale (SharedPreferences ''app_locale'') for send-push-notification.';
