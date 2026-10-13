-- Migration: Canonical uniqueness for phones and national IDs
-- Date: 2026-10-13

-- 1. Ensure phone numbers are stored in canonical Egyptian mobile form (01XXXXXXXXX)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    WHERE c.conname = 'profiles_phone_number_canonical_format'
      AND c.conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_phone_number_canonical_format
      CHECK (phone_number IS NULL OR phone_number ~ '^01[0125][0-9]{8}$');
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 2. Canonical unique index for phone numbers (prevents different string forms)
CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_number_canonical_key
  ON public.profiles ((public.normalize_phone(phone_number)))
  WHERE phone_number IS NOT NULL;

-- 3. Canonical unique index for national IDs (fold Arabic-Indic digits)
CREATE UNIQUE INDEX IF NOT EXISTS profiles_national_id_canonical_key
  ON public.profiles ((translate(national_id, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')))
  WHERE national_id IS NOT NULL AND national_id <> '';

-- ROLLBACK:
-- DROP INDEX IF EXISTS public.profiles_national_id_canonical_key;
-- DROP INDEX IF EXISTS public.profiles_phone_number_canonical_key;
-- ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_phone_number_canonical_format;