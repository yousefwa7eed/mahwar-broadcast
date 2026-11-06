-- =============================================================================
-- add_get_public_profiles_batch_rpc (applied to live as 20261106133142)
--
-- Why: the provider dashboard
-- (lib/features/provider_home/provider_home_screen.dart::_enrichActiveOrders)
-- loaded up to 20 active orders and then called get_public_profile(p_user_id)
-- once per distinct car_owner_id, sequentially, re-running on every realtime
-- order event — an N+1. This set-returning variant replaces the loop with ONE
-- call (client-side: batched owner names + parallel bounded reverse
-- geocoding, same commit).
--
-- Security posture — deliberately IDENTICAL to get_public_profile as hardened
-- in 20261105183456_reharden_admin_aal2_and_strip_public_profile_phone:
--   * Returns full_name / role / avatar_id / avatar_url only. NEVER
--     phone_number — owner contact is released only by get_order_contact()
--     once the order is confirmed (Stage-B invariant, unchanged).
--   * Per-id access rule is the same semi-join: caller owns the row OR shares
--     an order with the target. Ids failing the rule are simply ABSENT from
--     the result — fail closed; no enumeration oracle is created: a caller
--     learns nothing about profiles they are not already transacting with.
--   * Input cap of 50 bounds one call's work; the dashboard sends <= 20.
--     Verified against the live project: a 51-id call raises
--     GPP_TOO_MANY_IDS, and a call with no JWT session returns 0 rows even
--     for real profile ids.
--   * SECURITY DEFINER + search_path='' because RLS hides other profiles;
--     the WHERE rule above IS the authorization, same as the single-id fns.
--   * Grants mirror the single-id function: no anon, authenticated +
--     service_role only. The single-id get_public_profile(uuid) is left
--     UNTOUCHED for its remaining row callers (notification_detail_screen).
-- =============================================================================

drop function if exists public.get_public_profiles(uuid[]);

create or replace function public.get_public_profiles(p_user_ids uuid[])
returns table(user_id uuid, full_name text, role public.user_role, avatar_id text, avatar_url text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_ids is null then
    return;
  end if;

  if coalesce(array_length(p_user_ids, 1), 0) > 50 then
    raise exception 'GPP_TOO_MANY_IDS: at most 50 ids per call';
  end if;

  return query
  select
    pf.id,
    pf.full_name,
    pf.role,
    pf.avatar_id,
    pf.avatar_url
  from public.profiles pf
  where pf.id = any (p_user_ids)
    and (
      auth.uid() = pf.id
      or exists (
        select 1
        from public.orders o
        where (o.car_owner_id = pf.id and o.provider_id = auth.uid())
           or (o.provider_id = pf.id and o.car_owner_id = auth.uid())
      )
    );
end;
$$;

comment on function public.get_public_profiles(uuid[]) is
  'Batch identity lookup for parties who share orders with the caller. '
  'Never returns phone_number: owner contact details are released only by '
  'get_order_contact() once an order is confirmed.';

revoke all on function public.get_public_profiles(uuid[]) from public;
revoke all on function public.get_public_profiles(uuid[]) from anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;
grant execute on function public.get_public_profiles(uuid[]) to service_role;
