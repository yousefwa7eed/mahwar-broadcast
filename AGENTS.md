# AGENTS.md — Mahwar (محور)

Bilingual (Arabic-first) roadside-assistance marketplace. A car owner requests a service; nearby
providers bid a price; the owner confirms; the order is tracked, completed, and rated.

Three codebases live in this repo:

| Path | Stack | Notes |
|---|---|---|
| `lib/`, `android/`, `ios/` | Flutter (Dart `^3.12.1`), `flutter_bloc`, `go_router ^18` | the shipping app |
| `supabase/` | Postgres migrations (88+), RLS, Deno Edge Functions | the entire backend — all business logic is `SECURITY DEFINER` SQL |
| `admin-dashboard/` | Vite 7 + TypeScript, hand-written DOM (no UI framework), `@supabase/supabase-js` | internal ops console ("برج مراقبة محور"), read-only admin RPCs |

Live Supabase project ref: `trgesfzojaoirutkkfcs`.

## Commands

```bash
flutter pub get
flutter gen-l10n                 # regenerate localizations after ANY .arb edit
flutter analyze
flutter test                     # ~300 unit/widget tests in test/
flutter run --dart-define=OTP_DBG_BYPASS=true   # dev only, skips phone OTP
patrol test                      # real-device integration (needs a real test account)

cd admin-dashboard && npm install && npm run dev
```

There is **no CI** (`.github/` does not exist). Run `flutter analyze` and `flutter test` yourself
before declaring work done. `analysis_options.yaml` is plain `flutter_lints` v6 with no overrides.

## Architecture

Feature-first, and deliberately **flat** — there is no `data/domain/presentation` split and no
repository layer.

- `lib/features/<feature>/<name>_screen.dart` + optional `<feature>/widgets/`. 16 features.
- `lib/core/` holds everything shared: `auth/`, `router/`, `services/`, `models/`, `errors/`,
  `widgets/`, `theme/`, `constants/`, `settings/`, `notifications/`, `config/`.
- **Only 4 Cubits exist**, all in `lib/core/`: `AuthCubit`, `ProfileCubit`, `NotificationCubit`,
  `AppSettingsCubit`. Registered in `MultiBlocProvider` in `lib/main.dart`. There are **zero Bloc
  classes** — do not introduce them. `lib/core/bloc/` is an empty leftover directory.
- Events/states are plain Dart classes extending `Equatable`. **No freezed, no codegen** for models
  (`.freebuff/` at root is a stale artifact; `pubspec.yaml` has no freezed dependency).
- Feature screens call `Supabase.instance.client` **directly** (~39 call sites). This is the
  established pattern — follow it rather than inventing a repository abstraction. Singletons use
  `X.instance` (`PushNotificationService`, `ServiceTypeDirectory`, `ScreenTimeService`). No get_it.
- Navigation: one global `final GoRouter appRouter` in `lib/core/router/app_router.dart`. Flat route
  list, every `GoRoute` has both `path` and a kebab-case `name`. Parameters go through **query
  parameters** (or `extra` for full objects like `NotificationModel`).

## i18n — strict rules

Arabic is the source of truth. Getting this wrong silently breaks the app.

1. **`lib/l10n/app_ar.arb` is the template** (`l10n.yaml`). Add every new key to `app_ar.arb`
   **and** `app_en.arb` in the same change.
2. The generated files `lib/l10n/app_localizations{,_ar,_en}.dart` are **committed to git, not
   ignored**. Never hand-edit them — edit the ARB files and run `flutter gen-l10n`, then commit the
   regenerated output.
3. Access pattern is nullable **with a hardcoded Arabic fallback**, used ~174 times:
   ```dart
   final l10n = AppLocalizations.of(context);
   Text(l10n?.signOut ?? 'تسجيل الخروج')
   ```
   There is no `context.l10n` extension. Keep the `?? '…'` fallback so strings still render if
   localizations fail to load.
4. Direction is locale-driven (`AppSettingsCubit`, default `Locale('ar')`, persisted in
   SharedPreferences key `app_locale`). Use `EdgeInsetsDirectional` / `Directionality` only where
   direction must be forced. Fonts: Cairo = Arabic, Poppins = English, Zain = display; the theme
   sets Cairo globally.
5. **Push/in-app notification text lives in two places that must stay in sync.** Server-side strings
   are in `supabase/functions/send-push-notification/notification_text.ts`; client-side rendering is
   in `lib/core/models/notification_model.dart` from ARB keys. The mapping table (edge branch → ARB
   key) is documented in the header comment of `notification_text.ts`. Changing one without the
   other produces notifications whose push text and in-app text disagree.
   `test/notification_localization_test.dart` guards part of this.
6. Recipient language comes from `profiles.language` (`'ar'` default). The client mirrors its locale
   there via `AppSettingsCubit._pushLanguage`. Currency renders as `ج.م` (ar) / `EGP` (en).

## Supabase migrations — strict rules

The project is **not linked to the Supabase CLI** (`supabase/config.toml` has only the local
default; there is no `.temp/` and no project ref). Migrations are applied to the live project
first, then committed.

- Filename: `supabase/migrations/<YYYYMMDDHHMMSS>_<snake_case_description>.sql`.
- **The timestamp in the filename is the timestamp the SQL was actually applied to the live
  project**, not the time you wrote the file. Evidence: commit `4ac409e` "(applied as
  20261016015236)", commit `6182d69` "add applied migrations with live versions", and migration
  headers saying "verified against the live project".
- Therefore: never invent a filename timestamp for SQL that has not been applied. Apply it, read
  back the real version, then name the file. Record it in the commit message as `(applied as …)`.
- RLS policies go **inline in the same migration** as the table they protect.
- Admin tables (`admins`, `admin_audit_log`) follow a hardened pattern: RLS **enabled + FORCE**,
  **zero policies**, all grants revoked from `anon`/`authenticated`, reachable only through
  `SECURITY DEFINER` functions. Do not add direct policies to them.
- Some Storage policies exist only in the Supabase dashboard and not in any migration (known drift).
  **New storage rules must be written as migrations.**
- Migrations are heavily commented in mixed Arabic/English explaining the threat model. Match that
  style — the comments are the security documentation.

## Live database access (Supabase MCP)

Two MCP servers are configured in Qoder:

| Server | Endpoint | Scope |
|---|---|---|
| `plugin:supabase:supabase` | `https://mcp.supabase.com/mcp?features=docs` | docs only — its single tool is `search_docs` |
| `supabase_live` (custom, user scope) | `https://mcp.supabase.com/mcp?project_ref=trgesfzojaoirutkkfcs` | full read/write on the live project |

`supabase_live` authenticates via Supabase OAuth as the project owner and exposes `list_tables`,
`execute_sql`, `apply_migration`, `deploy_edge_function`, `get_advisors`, `list_migrations`,
`query_logs`, `generate_typescript_types` and branching tools. Its token is bound to
`trgesfzojaoirutkkfcs` alone.

- Schema reads, `list_migrations`, `get_advisors` and read-only `execute_sql` are always fine.
- `apply_migration`, and `execute_sql` containing DML or DDL, **write to production** and fall under
  the "ask first" rule in the working agreement.

## Security invariants — do not break these

- **Owner phone privacy (Stage B).** The owner's phone number reaches a provider **only after the
  order is `confirmed`**, and **only** through the `get_order_contact` RPC
  (`lib/features/orders/widgets/order_contact_card.dart`). Never read phone from `orders` or
  `profiles` directly, never re-add a `share_phone` option to create-order, never surface
  `order.ownerPhone`. See commits `591932e`, `f099e39`, `3512c90`, `49ef2ee` and migration
  `20261013231450_add_get_order_contact_and_harden_phone.sql`.
- **Role resolution.** Role comes **only** from `profiles.role` on the server.
  `AuthService.getServerRole()` must never fall back to `user_metadata`, and
  `AppRole.tryParse` must keep returning `null` for unknown values — **never default to
  `car_owner`**. A silent default is a privilege escalation.
- **Anti-enumeration.** Signup errors may reveal only the *role* of an existing account
  (`ACCOUNT_EXISTS_AS:<role>`), never a phone number or national ID. Recovery-OTP send errors
  deliberately collapse `user_not_found` / `phone_not_confirmed` / `phone_only_account_blocked`
  into one neutral message. Do not "improve" these into specific errors.
- **`ORDER_EVENT_SECRET` is a master key** guarding every sensitive edge function. Never log it,
  never commit it, never add it to a client bundle. Same for `SUPABASE_SERVICE_ROLE_KEY`,
  `FCM_SERVICE_ACCOUNT_JSON`, `ZADX_API_KEY`/`ZADX_API_SECRET`, `SMS_HOOK_SIGNING_SECRET`.
- **`send-sms-hook` must never return 429 or 503** — deliberate, to avoid GoTrue retry storms. Its
  budget caps come from the `sms_cap_config` table.
- Provider contact details are visible pre-order to any authenticated user via
  `get_nearest_providers` / `get_provider_details` (accepted product decision, tracked as M-C).
  **Do not widen this exposure further.**
- The anon key in `lib/core/config/app_config.dart` is public by design and overridable via
  `--dart-define`. That file is the single source for both `Supabase.initialize` and the isolated
  client used for password verification.

## Error handling contract

The server raises `CODE: message`; the token before the first colon is the code. The client **never
shows raw server text** — it maps codes to ARB strings, and every mapper ends in a generic fallback.

Three mappers, each with its own domain:
- `lib/core/errors/rpc_error_translator.dart` — order/RPC codes (`ORDER_NOT_FOUND`, `NOT_OWNER`,
  `PHONE_NOT_VERIFIED`, `PROVIDER_UNAVAILABLE`, …) plus PostgREST `23505`. Has a `_knownCodes`
  whitelist: **add new server codes there** or they fall through to the generic message.
- `lib/core/auth/signup_error_mapper.dart` — the `handle_new_user` trigger codes.
- `lib/core/auth/otp_error_mapper.dart` — GoTrue codes.

When you add a new `RAISE 'CODE: …'` in SQL, add the code to the matching mapper and an ARB key pair
in the same change.

## Testing

- `test/` — ~36 files. Fake the auth boundary with `test/fakes/fake_auth_service.dart`
  (`FakeAuthService extends AuthService`, injectable canned errors). `AuthService` is the only
  service abstracted for testability.
- High-value existing suites to keep green: the three error mappers, `auth_cubit_test`,
  `phone_verification_gate_test`, `login_navigation_gate_test`, `logout_coordinator_test`,
  `home_route_test`, `order_rpc_params_test`, `provider_heartbeat_params_test`,
  `notification_localization_test`.
- `integration_test/app_test.dart` is patrol-based and uses a **real test account** — it is not
  runnable without credentials. `patrol_test/test_bundle.dart` is generated; do not edit or commit
  changes to it.

## Known open TODOs

- **Admin MFA is temporarily disabled.** `BUILD_SKIP_MFA = true` in `admin-dashboard/src/main.ts`
  and server-side `is_admin()` is relaxed to match. The re-hardening migration
  `20261017020099_restore_admin_security.sql` is **referenced in that comment but does not exist in
  `supabase/migrations/`**. Re-hardening means writing that migration *and* flipping the flag.
- Storage policy drift (see migrations section).
- **Migration file/DB drift (measured 2026-10-21 against `supabase_migrations.schema_migrations`).**
  92 migrations are applied live; `supabase/migrations/` holds 88 files. Only 19 filenames carry the
  real applied version. 61 files have the right description but a synthetic round timestamp
  (`…000000`, `…120000`), 14 applied migrations have no file at all
  (`build_phase_relax_is_admin_temp`, `admin_rpc_require_admin_hotfix`, `fix_admin_page_paths_*`, …),
  and 8 files have no applied migration by name. Two description pairs are duplicated in the repo
  (`harden_order_state_transitions`, `role_locked_entrypoints`). Reconcile against
  `select version, name from supabase_migrations.schema_migrations` before renaming anything.
- `delete-account` still uses the older `deno.land/std@0.224.0` + `esm.sh` import style while every
  other function uses `Deno.serve` + `jsr:@supabase/supabase-js@2`.
- No certificate pinning.

Prior analysis by the maintainer, worth reading before touching auth or orders:
`docs/security_audit_report_ar.md` (OWASP Top 10) and `docs/diagnostics_report_ar.md`. Several P0/P1
items in the diagnostics report have **already been fixed** — verify against current code before
re-fixing.

## Repo hygiene

- `ECC/` and `broadcast-tool/` are **nested git repositories committed as gitlinks with no
  `.gitmodules`** — they cannot be restored by cloning. Do not `git add` inside them, and do not
  commit their gitlink pointer changes.
- `gate_comp.txt`, `gate_dbg.txt`, `gate_dbg2.txt`, `gate_now.txt`, `gate_v3.txt`, `gate_v4.txt`,
  `gate_v5.txt` are tracked `flutter test` console dumps from a past debugging session. **Do not add
  more scratch dumps**; prefer deleting these.
- Never commit: `admin-dashboard/.env`, `*.log`, `dist/`, `node_modules/`, `desktop.ini`,
  `*.dart.tmp` (one exists at `lib/features/orders/widgets/order_contact_card.dart.tmp`), or the
  root one-off scripts `add_keys2.py` / `fix_owner.py`.
- Commit messages follow Conventional Commits with a scope, e.g.
  `feat(i18n): …`, `fix(client): …`, `chore(db): …`, `refactor(auth): …`.

## Working agreement for agents

**Ask before doing any of these** — they touch shared/live state and are hard to reverse:

- Applying SQL to the live Supabase project, or running/deploying a migration.
- Deploying an Edge Function (`supabase functions deploy`).
- Anything that writes to production data (broadcasts, bans, account deletion).
- `git push`, force-push, or any branch/history rewrite.

Reading the live schema, running read-only SQL, and inspecting logs is always fine.

Local file edits, `flutter analyze`, `flutter test`, and building are free to run without asking.
