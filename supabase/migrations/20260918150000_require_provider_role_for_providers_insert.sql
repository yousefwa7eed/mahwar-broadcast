-- Migration: require provider role for providers INSERT (M2).
-- Date: 2026-09-18
--
-- The `Users can insert own provider profile` policy only checked
-- `auth.uid() = id`, so any authenticated car_owner could insert a provider
-- row for themselves: appear in the public directory and receive order pushes
-- without ever being a provider.
--
-- The Flutter app never inserts into `providers` directly — rows are created
-- by the SECURITY DEFINER `handle_new_user` trigger at signup (RLS-bypassing).
-- The policy is pure client surface, so it can be tightened without breaking
-- onboarding: an insert is only legal when the caller's profile row has
-- role = 'provider'.

drop policy if exists "Users can insert own provider profile" on public.providers;

create policy "Users can insert own provider profile"
on public.providers
for insert
to public
with check (
  auth.uid() = id
  and exists (
    select 1
    from public.profiles pf
    where pf.id = auth.uid()
      and pf.role = 'provider'::public.user_role
  )
);