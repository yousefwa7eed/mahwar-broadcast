-- Migration: Unify phone number format for reliable phone/email login
-- Date: 2026-08-28
-- Fixes conflicts where the same phone number was stored in different formats
-- (+2010... / 002010... / 010... / with spaces or dashes) causing login failures
-- and duplicate accounts.

-- ============================================================================
-- 1. normalize_phone(text): strips separators and folds +20/0020 into leading 0
-- ============================================================================
CREATE OR REPLACE FUNCTION public.normalize_phone(p_phone text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_phone IS NULL THEN NULL
        WHEN left(translate(p_phone, ' -()', ''), 3) = '+20' THEN '0' || substr(translate(p_phone, ' -()', ''), 4)
        WHEN left(translate(p_phone, ' -()', ''), 4) = '0020' THEN '0' || substr(translate(p_phone, ' -()', ''), 5)
        ELSE translate(p_phone, ' -()', '')
    END;
$$;

GRANT EXECUTE ON FUNCTION public.normalize_phone(text) TO anon;
GRANT EXECUTE ON FUNCTION public.normalize_phone(text) TO authenticated;

-- ============================================================================
-- 2. get_email_by_phone: look up using the normalized phone instead of raw text
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_email_by_phone(p_phone text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_email text;
BEGIN
    SELECT email INTO v_email
    FROM public.profiles
    WHERE phone_number = public.normalize_phone(p_phone)
    LIMIT 1;

    RETURN v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_email_by_phone(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_email_by_phone(text) TO authenticated;

-- ============================================================================
-- 3. handle_new_user: store phone_number in normalized format and check
--    duplicates against normalized values (prevents duplicate accounts)
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
    -- Normalize the phone number at storage time
    v_phone_number := public.normalize_phone(NEW.raw_user_meta_data ->> 'phone_number');
    v_national_id  := NEW.raw_user_meta_data ->> 'national_id';
    v_role         := COALESCE((NEW.raw_user_meta_data ->> 'role')::public.user_role, 'car_owner'::public.user_role);

    -- Generate email if not provided
    IF NEW.email IS NULL OR NEW.email = '' THEN
        v_email := COALESCE(v_phone_number, '') || '@mahwar.app';
    ELSE
        v_email := NEW.email;
    END IF;

    -- Check for duplicate phone_number (using normalized comparison on both sides)
    IF v_phone_number IS NOT NULL AND v_phone_number != '' THEN
        IF EXISTS (
            SELECT 1 FROM public.profiles
            WHERE phone_number = v_phone_number
               OR public.normalize_phone(phone_number) = v_phone_number
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