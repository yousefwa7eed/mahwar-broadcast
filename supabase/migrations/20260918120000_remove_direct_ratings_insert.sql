-- Migration: remove direct ratings INSERT path (H2).
-- Date: 2026-09-18
--
-- The `Owners rate orders` INSERT policy only checked `auth.uid() = user_id`.
-- Combined with the (now fixed, H3) permissive orders INSERT, an authenticated
-- attacker could fabricate a completed order and insert a 1-star rating on any
-- provider, poisoning `avg_rating` in the public directory.
--
-- The Flutter app submits ratings exclusively through the guarded
-- `rate_provider` RPC (lib/features/request_tracking/... and
-- lib/features/owner_home/widgets/provider_rating_dialog.dart); `from('ratings')`
-- is only ever SELECT. The RPC already enforces: caller owns the order
-- (IS DISTINCT FROM guard + anon revoked), provider assigned, rating 1-5,
-- order status = 'completed', and one rating per order (UNIQUE(order_id)).
-- Direct table INSERT is therefore removed: rating creation is RPC-only.

drop policy if exists "Owners rate orders" on public.ratings;