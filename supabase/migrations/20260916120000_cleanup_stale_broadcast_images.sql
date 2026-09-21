-- =============================================================================
-- Daily cleanup of stale broadcast images.
--
-- Why: broadcast notifications store an optional image as an arbitrary
-- external URL inside notifications.metadata->'image_url' (there is NO
-- Supabase Storage object for broadcasts — the owner pastes an external URL).
-- Keeping those hotlinks alive forever means every recipient's device fetches
-- an image that may no longer exist, or that outlives the offer it advertised.
-- So older than 15 days the image reference is dropped from the row — the
-- notification itself (title / body / created_at) is fully preserved, and the
-- app already renders a null/missing image gracefully (guard + errorBuilder).
--
-- Mirrors the in-database cron pattern from in_db_auto_cancel: a direct SQL
-- call scheduled via pg_cron (the edge-function pipeline proved unreliable in
-- production). Runs daily at 00:00 UTC.
-- =============================================================================

-- 1) The cleanup job.
create or replace function public.cleanup_stale_broadcast_images()
returns integer
language sql
security definer
set search_path = ''
as $$
  with cleared as (
    update public.notifications
    set metadata = metadata - 'image_url'
    where type = 'broadcast'
      and metadata ? 'image_url'
      and created_at < now() - interval '15 days'
    returning 1
  )
  select count(*)::integer from cleared;
$$;

-- Cron-only function: not meant to be called by clients.
revoke execute on function public.cleanup_stale_broadcast_images() from public, authenticated;

-- 2) Schedule it daily (00:00 UTC).
select cron.schedule('cleanup-stale-broadcast-images', '0 0 * * *',
                     'select public.cleanup_stale_broadcast_images();');