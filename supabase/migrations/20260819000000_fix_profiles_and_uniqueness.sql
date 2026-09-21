-- Migration: Fix handle_new_user trigger and add uniqueness constraints
-- Date: 2026-08-19

-- ============================================================================
-- 1. Add UNIQUE constraint on profiles.phone_number
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'profiles_phone_number_unique'
          AND conrelid = 'public.profiles'::regclass
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_phone_number_unique UNIQUE (phone_number);
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- 2. Add partial unique index on profiles.national_id
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'profiles_national_id_unique'
          AND tablename = 'profiles'
          AND schemaname = 'public'
    ) THEN
        CREATE UNIQUE INDEX profiles_national_id_unique
            ON public.profiles (national_id)
            WHERE national_id IS NOT NULL AND national_id != '';
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- 3. Fix existing profiles with null full_name
-- ============================================================================
UPDATE public.profiles
SET full_name = COALESCE(
    SPLIT_PART(email, '@', 1),
    'مستخدم'
)
WHERE full_name IS NULL;

-- ============================================================================
-- 4. Replace handle_new_user trigger function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_full_name      text;
    v_phone_number   text;
    v_national_id    text;
    v_role           public.user_role;
    v_email          text;
    v_has_vehicle    boolean;
    v_car_make       text;
    v_car_model      text;
    v_car_year       integer;
    v_specializations text[];
BEGIN
    -- Extract metadata
    v_full_name    := NEW.raw_user_meta_data ->> 'full_name';
    v_phone_number := NEW.raw_user_meta_data ->> 'phone_number';
    v_national_id  := NEW.raw_user_meta_data ->> 'national_id';
    v_role         := COALESCE((NEW.raw_user_meta_data ->> 'role')::public.user_role, 'car_owner'::public.user_role);

    -- Generate email if not provided
    IF NEW.email IS NULL OR NEW.email = '' THEN
        v_email := (NEW.raw_user_meta_data ->> 'phone_number') || '@mahwar.app';
    ELSE
        v_email := NEW.email;
    END IF;

    -- Check for duplicate phone_number
    IF v_phone_number IS NOT NULL AND v_phone_number != '' THEN
        IF EXISTS (
            SELECT 1 FROM public.profiles
            WHERE phone_number = v_phone_number
        ) THEN
            RAISE EXCEPTION 'Profile with phone number % already exists', v_phone_number;
        END IF;
    END IF;

    -- Check for duplicate national_id
    IF v_national_id IS NOT NULL AND v_national_id != '' THEN
        IF EXISTS (
            SELECT 1 FROM public.profiles
            WHERE national_id = v_national_id
        ) THEN
            RAISE EXCEPTION 'Profile with national ID % already exists', v_national_id;
        END IF;
    END IF;

    -- Create profile with COALESCE to prevent null full_name
    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        phone_number,
        national_id,
        role,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        v_email,
        COALESCE(v_full_name, SPLIT_PART(v_email, '@', 1), 'مستخدم'),
        v_phone_number,
        CASE WHEN v_national_id = '' THEN NULL ELSE v_national_id END,
        v_role,
        now(),
        now()
    );

    -- Create provider record if role is provider
    IF v_role = 'provider'::public.user_role THEN
        INSERT INTO public.providers (id, created_at, updated_at)
        VALUES (NEW.id, now(), now());
    END IF;

    -- Create car_details if role is car_owner
    IF v_role = 'car_owner'::public.user_role THEN
        v_car_make  := NEW.raw_user_meta_data ->> 'car_make';
        v_car_model := NEW.raw_user_meta_data ->> 'car_model';
        v_car_year  := NULLIF(NEW.raw_user_meta_data ->> 'car_year', '')::integer;

        INSERT INTO public.car_details (
            user_id,
            car_make,
            car_model,
            car_year,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            v_car_make,
            v_car_model,
            v_car_year,
            now(),
            now()
        );
    END IF;

    -- Create provider_car_details if role is provider and has_vehicle
    IF v_role = 'provider'::public.user_role THEN
        v_has_vehicle := (NEW.raw_user_meta_data ->> 'has_vehicle')::boolean;
        IF v_has_vehicle IS TRUE THEN
            INSERT INTO public.provider_car_details (
                provider_id,
                vehicle_make,
                vehicle_model,
                vehicle_year,
                vehicle_plate,
                vehicle_color,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,
                NEW.raw_user_meta_data ->> 'vehicle_make',
                NEW.raw_user_meta_data ->> 'vehicle_model',
                NULLIF(NEW.raw_user_meta_data ->> 'vehicle_year', '')::integer,
                NEW.raw_user_meta_data ->> 'vehicle_plate',
                NEW.raw_user_meta_data ->> 'vehicle_color',
                now(),
                now()
            );
        END IF;
    END IF;

    -- Create provider specializations if role is provider
    IF v_role = 'provider'::public.user_role THEN
        v_specializations := ARRAY(SELECT jsonb_array_elements_text(
            COALESCE(NEW.raw_user_meta_data -> 'specializations', '[]'::jsonb)
        ));

        IF array_length(v_specializations, 1) > 0 THEN
            INSERT INTO public.provider_specializations (provider_id, service_type_id, created_at)
            SELECT
                NEW.id,
                s,
                now()
            FROM unnest(v_specializations) AS s
            WHERE s IS NOT NULL AND s != '';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- ============================================================================
-- 5. Ensure trigger exists on auth.users
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'on_auth_user_created'
          AND tgrelid = 'auth.users'::regclass
    ) THEN
        CREATE TRIGGER on_auth_user_created
            AFTER INSERT ON auth.users
            FOR EACH ROW
            EXECUTE FUNCTION public.handle_new_user();
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;
