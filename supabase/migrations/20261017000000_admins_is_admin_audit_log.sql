-- =============================================================================
-- Phase 5A foundation (read-only admin layer):
--   1) public.admins              -- the single admin account marker
--   2) public.is_admin()          -- SECURITY DEFINER gate: admin row AND aal2
--   3) public.admin_audit_log     -- append-only audit trail for admin actions
--
-- Scope decision (Yousef, 2026-10-16/17): 5A is READ-ONLY. NO moderation
-- columns on profiles, no flags, no orders board, no verification, no
-- services. Admin read RPCs arrive in a follow-up migration.
--
-- Security model:
--   * Both tables: RLS enabled + FORCE, NO policies, all grants revoked from
--     anon/authenticated. Nobody can read or write them through the public
--     Data API; only SECURITY DEFINER functions (future admin RPCs) touch them.
--     Same pattern as sms_send_logs / sms_cap_config (20260921000000).
--   * No public path inserts into admins: public signup (handle_new_user) and
--     every authenticated API path are revoked, so a normal user can never
--     become an admin. The only writer is the SQL editor / service_role.
--   * is_admin() fails CLOSED: it requires BOTH a row in admins AND the JWT
--     aal claim to be 'aal2' (TOTP MFA verified). A missing claim (anon,
--     non-JWT context) evaluates to false.
--
-- is_admin() is intentionally a plain boolean predicate. Admin RPCs call it
-- first and RAISE a clear error when it is false (pattern for 5A RPCs).
--
-- Runbook (create the admin, after enrolling TWO TOTP devices in the
-- Supabase dashboard for the admin's user):
--   1. Sign up / sign in the admin account once through the app or Auth API
--      (never via a role value -- roles are car_owner|provider only).
--   2. Enrollment: Dashboard -> Authentication -> Users -> [admin] -> MFA ->
--      enroll authenticator (do this on TWO devices; Supabase TOTP has no
--      recovery codes).
--   3. Grant admin (SQL editor, reviewed):
--        insert into public.admins (user_id)
--        values ('<auth.users.id>') on conflict do nothing;
--   4. Lockout recovery: delete the admins row the same way, sign in again
--      with the password, re-enroll MFA, re-insert the row.
--
-- Verify after applying (read-only):
--   select * from pg_policies where schemaname = 'public'
--     and tablename in ('admins', 'admin_audit_log');          -- expect 0 rows
--   select has_table_privilege('authenticated', 'public.admins', 'select');
--                                                            -- expect false
--   select public.is_admin();   -- expect false as anon/auth non-admin, true
--                               -- for the admin session with aal2.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. admins: exactly one row per admin account. No extra columns beyond what
--    5A needs; created_by records which account/operator granted it (NULL when
--    seeded from the SQL editor during onboarding).
-- ---------------------------------------------------------------------------
create table if not exists public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  note       text not null default ''
);

alter table public.admins enable row level security;
alter table public.admins force row level security;
revoke all on public.admins from anon, authenticated;

comment on table public.admins is
  'Admin allow-list for the Vercel admin dashboard. Insertion only via SQL editor/service_role; is_admin() also requires JWT aal2.';

-- ---------------------------------------------------------------------------
-- 2. admin_audit_log: every sensitive admin action writes one row from the
--    calling SECURITY DEFINER RPC (details carries RPC-specific jsonb, e.g.
--    {'reason': ...} or export scope). Never updated, never deleted.
-- ---------------------------------------------------------------------------
create table if not exists public.admin_audit_log (
  id             uuid primary key default gen_random_uuid(),
  admin_id       uuid not null references auth.users (id) on delete cascade,
  action         text not null,
  target_user_id uuid references auth.users (id) on delete set null,
  details        jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now()
);

create index if not exists admin_audit_log_created_at_idx
  on public.admin_audit_log (created_at desc);
create index if not exists admin_audit_log_admin_idx
  on public.admin_audit_log (admin_id, created_at desc);
create index if not exists admin_audit_log_target_idx
  on public.admin_audit_log (target_user_id, created_at desc);

alter table public.admin_audit_log enable row level security;
alter table public.admin_audit_log force row level security;
revoke all on public.admin_audit_log from anon, authenticated;

comment on table public.admin_audit_log is
  'Append-only audit trail written by every admin RPC (national id reveal, exports, moderation, notifications, flag/cap changes).';

-- ---------------------------------------------------------------------------
-- 3. is_admin(): SECURITY DEFINER predicate used as the FIRST check of every
--    admin RPC. Requires:
--      a) the caller (auth.uid()) has a row in public.admins, AND
--      b) the JWT aal claim is 'aal2' (password + TOTP verified this request).
--    Fails closed: missing uid / missing claim / unknown caller -> false.
-- ---------------------------------------------------------------------------
drop function if exists public.is_admin();

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

-- =============================================================================
-- ROLLBACK (manual, if needed):
--   drop function if exists public.is_admin();
--   drop table if exists public.admin_audit_log;
--   drop table if exists public.admins;
-- =============================================================================
