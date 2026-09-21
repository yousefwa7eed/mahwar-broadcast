-- =============================================================================
-- Realtime for providers.is_online on the provider's OWN row.
--
-- The provider home screen subscribes to postgres_changes on providers
-- filtered to the authenticated provider's id, so a cron-written is_online
-- flip propagates to the open screen instantly. This requires the table to
-- be a member of the supabase_realtime publication (RLS already permits the
-- provider to read their own row via "Provider manages own profile").
--
-- Idempotent: no-op if providers is already a member.
-- =============================================================================

do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'providers'
  ) then
    execute 'alter publication supabase_realtime add table public.providers';
  end if;
end;
$$;