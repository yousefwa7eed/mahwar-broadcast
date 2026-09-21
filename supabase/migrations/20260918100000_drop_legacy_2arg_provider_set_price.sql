-- Migration: Drop legacy 2-arg provider_set_price (H1 sub-fix 4).
-- Date: 2026-09-18
--
-- Dead code. The app only calls the 5-arg variant. The 2-arg one is the
-- only remaining RPC without SET search_path = '' (config null in pg_proc)
-- and it could not be hardened anyway; removing it closes the last weak
-- order-lifecycle entry point.

drop function if exists public.provider_set_price(uuid, numeric);