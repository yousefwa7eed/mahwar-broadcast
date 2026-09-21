-- Migration: scope get_public_profile to order participants (H4).
-- Date: 2026-09-18
--
-- `get_public_profile(p_user_id)` was SECURITY DEFINER with anon+PUBLIC+
-- authenticated EXECUTE and returned full_name / phone_number / role / avatar
-- for ANY uuid — user enumeration and arbitrary phone PII.
--
-- Legitimate callers are order participants fetching the OTHER party's profile:
--   - provider_offer_price_screen.dart:204   order.carOwnerId (gated by share_phone)
--   - provider_home_screen.dart:264          car_owner of active orders
--   - an owner may fetch their own profile (self)
--
-- Fix: revoke anon + PUBLIC; grant authenticated; scope the query to
--   auth.uid() = p_user_id                     (self)
--   OR an order shared by both (p_user_id and auth.uid() are participants).

revoke all on function public.get_public_profile(uuid) from public;
revoke all on function public.get_public_profile(uuid) from anon;
grant execute on function public.get_public_profile(uuid) to authenticated;

create or replace function public.get_public_profile(p_user_id uuid)
 returns table(full_name text, phone_number text, role user_role, avatar_id text, avatar_url text)
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  return query
  select
    pf.full_name,
    pf.phone_number,
    pf.role,
    pf.avatar_id,
    pf.avatar_url
  from public.profiles pf
  where pf.id = p_user_id
    and (
      auth.uid() = p_user_id
      or exists (
        select 1
        from public.orders o
        where (o.car_owner_id = p_user_id and o.provider_id = auth.uid())
           or (o.provider_id = p_user_id and o.car_owner_id = auth.uid())
      )
    );
end;
$function$;