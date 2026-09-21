# Mahwar Security Audit Report

- **Date:** 2026-09-18
- **Project:** `trgesfzojaoirutkkfcs` ("mahwar"), region eu-central-1, Postgres 17
- **Ground truth:** live database; repo migrations were cross-checked and **version drift exists** (several on-disk migrations were never applied, e.g. `20260820000001`, `20260902120000`).

---

## FIXED (this session)

### C1. `update_auth_email` — unguarded email takeover (was CRITICAL)
Live function was `SECURITY DEFINER`, `authenticated` EXECUTE, updating `auth.users.email` by arbitrary `p_user_id` with no owner check. The repo guard (`20260820000001_add_update_auth_email.sql`) had **never been applied** to the live DB.

**Fixed** via migration `20260918050000_fix_update_auth_email_ownership_guard.sql`:
- Body now raises `Cannot update another user's email` when `p_user_id IS DISTINCT FROM auth.uid()` (rejects non-owners and NULL/anon callers).
- `REVOKE ALL ... FROM PUBLIC, anon`; `GRANT EXECUTE ... TO authenticated`.
- Verified live: `anon_exec=false`, `auth_exec=true`.
- Legit caller (`lib/features/profile/edit_personal_info_screen.dart:75,102-105`) always passes `currentUser.id` → unaffected.

### C2. `public_provider_profiles` — anon PII exposure (was CRITICAL)
Postgres-owned (definer) view exposing every provider's name/phone/address/coordinates; SELECT was granted to `anon`. Advisor `security_definer_view` ERROR.

### H1. anon NULL-bypass on order-lifecycle RPCs (was HIGH) — see REMAINING HIGH ↓

**Fixed** via migration `20260918060000_fix_public_provider_profiles_anon_access.sql`:
- `REVOKE ALL ... FROM anon, PUBLIC`; `GRANT SELECT ... TO authenticated`.
- Verified live: `anon_select=false`, `auth_select=true`.
- `security_invoker=true` was **not** used on purpose: the view intentionally bypasses the own-row-only RLS on `providers`/`profiles`; with `security_invoker` the directory would return nothing and provider browsing would break. The advisor lint may still flag it — now benign for anon.
- `phone_number`/`address` are required by the details screen (call + address UI). `lat`/`lng` are used only server-side for `distance_meters`, not displayed to customers — candidate to trim from the *list* projection later.

---

## REMAINING HIGH

### H1 — anon NULL-bypass on ownership-guarded RPCs ✅ FIXED
The anon JWT has **no `sub`** → `auth.uid()` is `NULL`. Guards written `IF <id> <> auth.uid() THEN RAISE` evaluate `x <> NULL` → `NULL` → never raises. All order-lifecycle RPCs had `anon` EXECUTE *and* this bug, allowing an unauthenticated caller (the shipped anon key) to cancel/confirm/price/reject/rate/assign **any** order.

**Fix applied (migrations `20260918070000`–`20260918100000`), verified live:**
1. ✅ Revoked anon EXECUTE from all 11 order-lifecycle RPC signatures (PUBLIC + anon; `authenticated`/`service_role` retained). Verified `anon_exec=false` on all.
2. ✅ Rewrote guards to `auth.uid() IS NULL OR <id> IS DISTINCT FROM auth.uid()` on `owner_cancel_order`, `owner_confirm_price`, `rate_provider`, `assign_order_to_provider`, `provider_reject_order`, 5-arg `provider_set_price`. Each now also `SET search_path = ''`.
3. ✅ Re-applied the never-applied `20260902120000` hardening: `provider_set_price` (5-arg) and `provider_reject_order` now require `status = 'pending'` (→ `priced` / `rejected_by_provider` only).
4. ✅ Dropped the legacy 2-arg `provider_set_price` (dead code, lacked `search_path`).

The four WHERE-based functions (`owner_accept_price`, `owner_reject_price`, `provider_complete_order`, `set_order_attachments`) already failed closed (ownership in WHERE — NULL matches nothing) and now also have `anon_exec=false`.

Final sweep confirmed: every order-lifecycle RPC is `anon_exec=false`, `auth_exec=true`, and the mutable-entry ones (`rate_provider`, `assign_order_to_provider`, `owner_cancel_order`, `owner_confirm_price`, `provider_reject_order`, `provider_set_price`) carry the `IS DISTINCT FROM` guard; price/reject additionally enforce the `pending` precondition. Note: `DROP/CREATE` resets ACLs, so if a guarded RPC is ever recreated it must be re-revoked (the migrations re-grant `authenticated`; the revoke statements are inside `20260918070000`).

### H2 — rating integrity (table-level) ✅ FIXED
`ratings` INSERT policy was only `WITH CHECK auth.uid() = user_id`. Combined with the permissive `orders` INSERT (H3), an authenticated user could fabricate an order and insert an arbitrary rating on any provider, poisoning `avg_rating` in the public directory.
**Fix applied (migration `20260918120000_remove_direct_ratings_insert.sql`), verified live:** removed the `Owners rate orders` INSERT policy entirely — rating creation is now RPC-only. The app only ever used `rate_provider` (`request_tracking_screen.dart:322`, `provider_rating_dialog.dart:52`); `from('ratings')` is SELECT-only. The RPC already enforces owner-share (IS DISTINCT FROM guard), provider assigned, rating 1-5, `status='completed'`, and one rating per order (`UNIQUE(order_id)`). Verified as `authenticated` with spoofed JWT: direct rating INSERT → `42501` denied; `rate_provider` still executes (raises `ORDER_NOT_FOUND` on bogus id).

### H3 — `orders` INSERT over-permissive ✅ FIXED
Policy checked only `car_owner_id = auth.uid()`; **no CHECK on `status`**, so a client could fabricate orders with arbitrary `status`/`provider_id`/`offered_price`/provider-owned fields at creation — the fuel for the H2 rating attack.

**Fix applied (migration `20260918110000_tighten_orders_insert_policy.sql`), verified live:**
- INSERT `WITH CHECK` now additionally requires `status = 'pending'`, `provider_id IS NULL`, `offered_price IS NULL`, `provider_notes/eta_minutes/provider_attachments IS NULL`. Orders can only be created as fresh unassigned pending rows; assignments/price only via the guarded RPCs.
- Verified as `authenticated` with spoofed JWT: malicious insert (`status='completed'`, provider/price set) → `42501 new row violates row-level security policy`; legitimate pending insert passes and then rolled back.

Updated from:
Policy checked only `car_owner_id = auth.uid()`; **no CHECK on `status`** (default `'pending'` but overridable); the pre-insert trigger only sets `respond_deadline`. A client can set arbitrary `status`/`provider_id`/`offered_price`/`owner_phone` at creation.
Fix: BEFORE INSERT trigger forcing `status='pending'`, `provider_id=NULL`, `offered_price=NULL`, deriving `owner_phone` from the caller's profile; or introduce an order-creation RPC.

### H4 — `get_public_profile(p_user_id)` ✅ FIXED
SECURITY DEFINER, anon+authenticated EXECUTE → returned `full_name`, `phone_number`, `role`, avatar for **any** uuid (enumeration + phone PII). Legitimate callers are order participants fetching the other party (provider_offer_price_screen.dart:204 respecting `share_phone`; provider_home_screen.dart:264).

**Fixed via migration `20260918130000_scope_get_public_profile.sql`, verified live:**
- `REVOKE ... FROM PUBLIC, anon`; `GRANT EXECUTE ... TO authenticated`.
- Query now scoped: `auth.uid() = p_user_id` **or** `p_user_id` shares an order with the caller (either participant).
- Probes as `authenticated`: unrelated user → 0 rows; real provider fetching its order-partner owner (`47df26b8…` → `74ffaab2…`) → returns full row. `anon_exec=false`.

### H5 — `get_email_by_phone(p_phone)` ✅ FIXED (throttled wrapper, product-approved)
SECURITY DEFINER, **anon** EXECUTE → phone→email mapping (targeted phishing/ATO). The app calls it at **sign-in pre-auth** (`lib/core/auth/auth_cubit.dart:213-216`), so revoking anon breaks login. **Decision: throttle, keep login working.**

**Fixed via migration `20260918140000_throttle_get_email_by_phone.sql`, verified live:**
- Added `email_lookup_attempts` server-side table (RLS off; only reachable through the function).
- `get_email_by_phone` now enforces **max 5 lookups per phone per rolling hour** (`TOO_MANY_LOOKUPS`), purges attempts after 1 day, returns the email only if under the limit. Same normalization/lookup/return contract → **no Flutter change needed**.
- Verified as `anon`: 5 lookups pass, 6th raises `TOO_MANY_LOOKUPS`. `anon_exec` retained.

---

## MEDIUM

### M1 — Directory PII visible before any order/match (product decision, do NOT fix yet)
Any **authenticated** car_owner can currently view a provider's **full phone number and exact address** while just browsing the directory, before any order or match exists with that provider. Exposed via `get_nearest_providers` / `get_provider_details` (and the retained authenticated SELECT on `public_provider_profiles`).
- This is separate from the C2 anon fix (C2 removed anonymous access; this remains for authenticated users).
- The details screen legitimately needs the provider's phone (call button) and address once the owner engages with them.
- **Flag for product decision later:** restrict phone/address (and exact lat/lng) to after a match/assignment, e.g. push them only to an order participant, or read them via a scoped function on the order. Do **not** change now.

### M2 — `providers` INSERT self-service ✅ FIXED
`WITH CHECK auth.uid()=id` only, no role verification → a `car_owner` could create a provider row, appear in the public directory, and receive order pushes.

**Fixed via migrations `20260918150000` + `20260918151000`, verified live:**
- INSERT policy now also requires the caller's `profiles.role = 'provider'`.
- Dropped the permissive `Provider manages own profile` **ALL** policy (`WITH CHECK auth.uid()=id`), which OR-overrode the INSERT policy and re-granted self-insert. SELECT/UPDATE remain covered by the discrete self policies; DELETE isn't used (rows cascade with `profiles`, `providers_id_fkey ON DELETE CASCADE`).
- Probes as `authenticated`: car_owner self-insert → `42501`; real provider insert passes RLS and only hits PK conflict (`23505`). App never inserts `providers` directly (`handle_new_user` is SECURITY DEFINER), so onboarding is unaffected.

### M3 — Storage: permissive upload policy
`Allow Authenticated Uploads` (authenticated, `WITH CHECK bucket_id='order-attachments'` only) lets any authenticated user write to any path. The provider flow writes into the owner's folder (`orders/<carOwnerId>/provider_*.ext`), which doesn't match the scoped policy (`foldername[1]=auth.uid()`), so the permissive one is load-bearing. Fix (product decision): restructure paths (e.g. `orders/<orderId>/...`) and validate against `orders` so each party may only write to their own orders. Attachments are world-readable by design (public bucket + `getPublicUrl`).

### M4 — Assorted anon-executable functions ✅ FIXED
`insert_broadcast_notifications`, `is_provider_available_now`, `provider_availability_snapshot`, `server_now`, and the cron maintenance functions `expire_overdue_orders`, `flip_provider_availability_at_boundaries`, `cleanup_stale_broadcast_images` were all reachable by the anon key via the default PUBLIC grant.

**Fixed via migration `20260918160000_revoke_anon_assorted_functions.sql`, verified live:**
- Maintenance/edge-only (`expire_overdue_orders`, `flip_provider_availability_at_boundaries`, `cleanup_stale_broadcast_images`, `insert_broadcast_notifications`) → `service_role` only (`anon/auth = false`).
- App-called RPCs (`is_provider_available_now`, `provider_availability_snapshot`, `server_now`) → anon revoked, `authenticated` retained (all call sites are post-auth). `anon_exec=false` on all seven.

---

## LOW / hygiene

### Hardening pass ✅ FIXED — migration `20260918170000_low_hygiene_hardening_pass.sql`
- **`search_path` pinned** on `update_updated_at_column`, `normalize_phone`, `fold_phone_digits` (`SET search_path = ''`) → advisor `function_search_path_mutable` WARN cleared.
- **anon EXECUTE revoked** from trigger/event-trigger SECURITY DEFINER helpers (`guard_role_immutable`, `handle_new_user`, `handle_user_email_update`, `notify_push`, `notify_order_terminal_cleanup`, `sync_auth_role_from_profile`, `orders_apply_cancel_prefs`, `rls_auto_enable`) and from the RPCs `delete_user_account` (unused — the delete-account edge function uses service-role `cleanup_user_data`), `get_nearest_providers`, `get_provider_details`. `authenticated`/`service_role` retained; `supabase_auth_admin` retained on the `auth.users` triggers. → advisor `anon_security_definer_function_executable` down **12 → 1** (remaining one is `get_email_by_phone`, intentional per H5).
- Verified triggers still fire after the revoke: an authenticated `profiles` update advanced `updated_at` (via `update_updated_at_column`) with `guard_role_immutable` / `sync_auth_role_from_profile` running without error.
- Remaining advisor items are accepted/expected: `security_definer_view` on `public_provider_profiles` (C2, defensible — see note); `rls_enabled_no_policy` INFO on `email_lookup_attempts` (H5) and `order_event_secret` (server-only, no API access by design); `extension_in_public` for `cube`/`earthdistance`/`pg_net` (moving would risk `get_nearest_providers`); `authenticated_security_definer_function_executable` (legit app RPCs + unreachable trigger functions).

### Open (non-SQL)
- **Auth advisor:** `auth_leaked_password_protection` disabled — enable in Dashboard.
- **Rate limits / password policy** not inspectable via SQL (`auth.config` absent) — verify in Dashboard.
- **Flutter:** production URL + live anon JWT hardcoded as defaults (`lib/main.dart:20-28`); signup role is client-asserted via `?role=` (`lib/core/router/app_router.dart:51-64`, `lib/core/auth/auth_service.dart:51-52`); no router-level auth guard (enforcement delegated to RPCs/RLS). The anon JWT is safe to ship, but release builds should pass config via `--dart-define`.

---

## Suggested order to work through
1. ✅ **H1** (anon bypass) — fixed + verified.
2. ✅ **H3** (orders INSERT hardening) → then ✅ **H2** (ratings) — both fixed + verified.
3. ✅ **H4**, then ✅ **H5** — both fixed + verified.
4. ✅ **M2** (providers INSERT) and ✅ **M4** (assorted anon functions) — both fixed + verified.
5. **M1** (product decision — deferred, do NOT fix) and **M3** (product decision — path restructure + Flutter change).
6. ✅ **Hardening pass** (`search_path` + anon revokes) — fixed + verified.
7. Dashboard-only: enable leaked-password protection; verify rate limits/password policy (not reachable via SQL).