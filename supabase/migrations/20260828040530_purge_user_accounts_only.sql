-- Migration: Delete all user accounts (auth.users + profiles) only.
-- Keeps orders, car_details, providers history and storage attachments as reference.
-- Date: 2026-08-28

-- 1. Drop FK constraints that reference public.profiles so historical data survives
--    (car_details and orders are kept as reference; do not cascade-delete them)
ALTER TABLE IF EXISTS public.car_details DROP CONSTRAINT IF EXISTS car_details_user_id_fkey;
ALTER TABLE IF EXISTS public.orders DROP CONSTRAINT IF EXISTS orders_car_owner_id_fkey;
ALTER TABLE IF EXISTS public.orders DROP CONSTRAINT IF EXISTS orders_provider_id_fkey;

-- 2. Delete all auth users. profiles rows cascade automatically via
--    profiles_id_fkey (profiles.id -> auth.users.id ON DELETE CASCADE).
--    providers/notifications empty -> no cascade side effects.
DELETE FROM auth.users;