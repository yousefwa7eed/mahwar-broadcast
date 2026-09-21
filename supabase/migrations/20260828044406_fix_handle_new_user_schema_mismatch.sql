-- Migration: Fix handle_new_user to match the actual table columns
-- Date: 2026-08-28
-- The previous trigger referenced car_details(car_make, car_model, car_year) and
-- provider_car_details(vehicle_make, vehicle_model, ...) which do NOT exist in the
-- deployed schema. The real columns are make/model/year/plate_number/color.
-- This caused: "column car_make of relation car_details does not exist"
-- (Database error saving new user).

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
        INSERT INTO public.providers (
            id,
            workshop_name,
            address,
            latitude,
            longitude,
            support_scope,
            has_vehicle,
            vehicle_specs,
            created_at
        ) VALUES (
            NEW.id,
            NEW.raw_user_meta_data ->> 'workshop_name',
            NEW.raw_user_meta_data ->> 'address',
            NULLIF(NEW.raw_user_meta_data ->> 'latitude', '')::double precision,
            NULLIF(NEW.raw_user_meta_data ->> 'longitude', '')::double precision,
            COALESCE((NEW.raw_user_meta_data ->> 'support_scope')::public.support_scope, 'both'::public.support_scope),
            COALESCE((NEW.raw_user_meta_data ->> 'has_vehicle')::boolean, false),
            NEW.raw_user_meta_data ->> 'vehicle_specs',
            now()
        );
    END IF;

    -- Create car_details if role is car_owner
    IF v_role = 'car_owner'::public.user_role THEN
        INSERT INTO public.car_details (
            user_id,
            make,
            model,
            year,
            plate_number,
            color,
            created_at
        ) VALUES (
            NEW.id,
            NEW.raw_user_meta_data ->> 'car_make',
            NEW.raw_user_meta_data ->> 'car_model',
            NULLIF(NEW.raw_user_meta_data ->> 'car_year', '')::integer,
            NEW.raw_user_meta_data ->> 'car_plate_number',
            NEW.raw_user_meta_data ->> 'car_color',
            now()
        );
    END IF;

    -- Create provider_car_details if role is provider and has_vehicle
    IF v_role = 'provider'::public.user_role THEN
        v_has_vehicle := COALESCE((NEW.raw_user_meta_data ->> 'has_vehicle')::boolean, false);
        IF v_has_vehicle IS TRUE THEN
            INSERT INTO public.provider_car_details (
                provider_id,
                make,
                model,
                year,
                plate_number,
                color,
                created_at
            ) VALUES (
                NEW.id,
                NEW.raw_user_meta_data ->> 'vehicle_make',
                NEW.raw_user_meta_data ->> 'vehicle_model',
                NULLIF(NEW.raw_user_meta_data ->> 'vehicle_year', '')::integer,
                NEW.raw_user_meta_data ->> 'vehicle_plate',
                NEW.raw_user_meta_data ->> 'vehicle_color',
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
            INSERT INTO public.provider_specializations (provider_id, service_type_id)
            SELECT
                NEW.id,
                s
            FROM unnest(v_specializations) AS s
            WHERE s IS NOT NULL AND s != '';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;