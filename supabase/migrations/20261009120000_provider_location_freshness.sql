-- =============================================================================
-- Provider location freshness metadata.
--
-- Every provider location write now stamps WHEN it happened (location_updated_at,
-- UTC) and with WHAT horizontal accuracy in meters (location_accuracy). Clients
-- use this to decide whether a new GPS fix deserves a DB write:
--   * write if there is no known fresh location (NULL updated_at)
--   * write if the stored one is stale (older than the freshness window)
--   * write if the new fix is at least as accurate AND moved beyond a threshold
--   * never overwrite a fresh, more-accurate stored fix with a worse one
--
-- Both columns are nullable on purpose: pre-existing rows keep NULL updated_at,
-- which the client treats as "unknown -> writable", and accuracy may be unknown
-- for old rows (treated as "no better accuracy known").
--
-- get_nearest_providers and the owner flow are intentionally UNCHANGED here.
-- =============================================================================

alter table public.providers
  add column if not exists location_updated_at timestamptz,
  add column if not exists location_accuracy double precision;

comment on column public.providers.location_updated_at is
  'UTC time of the last provider location write; NULL until the first write.';
comment on column public.providers.location_accuracy is
  'Horizontal accuracy in meters of the last provider location fix; NULL until the first write.';