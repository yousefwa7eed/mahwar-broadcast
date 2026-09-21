-- Migration: Add avatar_id column to profiles for avatar selection
-- This stores the selected avatar identifier (e.g., 'car_owner_1', 'provider_3')
-- Separate from avatar_url which is for real photo uploads

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS avatar_id TEXT;

COMMENT ON COLUMN public.profiles.avatar_id IS 'Selected avatar identifier from predefined avatar sets (car_owner_* / provider_*)';

-- Optional: index for faster lookups by avatar_id
CREATE INDEX IF NOT EXISTS idx_profiles_avatar_id ON public.profiles(avatar_id);