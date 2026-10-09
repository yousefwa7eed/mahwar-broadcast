-- =============================================================================
-- Role-locked entry points: report an existing-account conflict at signup
-- surfacing ONLY the existing role (never phone / national id / email).
--
-- Scope of change: the two duplicate-check blocks inside public.handle_new_user()
-- are replaced. Every other line is byte-for-byte the currently deployed function
-- (verified against the live database via pg_get_functiondef before writing this
-- file; the live definition matched the repo definition exactly).
--
-- New error code (message exposes ONLY the role):
--   ACCOUNT_EXISTS_AS:<role>     where <role> = car_owner | provider
--
-- The client (lib/core/auth/signup_error_mapper.dart) maps this code to a clear
-- Arabic message telling the user to sign in from the matching page.
--
-- Unchanged and intentionally left in place:
--   * unique constraints: UNIQUE(email), UNIQUE(phone_number), UNIQUE(national_id)
--   * trigger profiles_role_immutable (BEFORE UPDATE) -> role frozen at signup
--   * trigger on_profile_role_updated (AFTER UPDATE)  -> metadata sync on admin flip
--   * trigger on_auth_user_created  (AFTER INSERT)    -> calls this function
--
-- No existing duplicates exist in production (all three columns are UNIQUE, so a
-- second row for the same value is impossible) — audit query at the bottom.
-- =============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_full_name      text;
    v_phone_number   text;
    v_national_id    text;
    v_role_text      text;
    v_role           public.user_role;
    v_email          text;
    v_has_vehicle    boolean;
    v_specializations text[];
    v_support_scope  public.support_scope;
    v_workshop_name  text;
    v_address        text;
    v_lat            text;
    v_lon            text;
    v_lat_num        double precision;
    v_lon_num        double precision;
    v_existing_role  text;
begin
    -- Extract metadata
    v_full_name    := NEW.raw_user_meta_data ->> 'full_name';
    v_phone_number := public.normalize_phone(NEW.raw_user_meta_data ->> 'phone_number');
    v_national_id  := NEW.raw_user_meta_data ->> 'national_id';
    v_role_text    := NEW.raw_user_meta_data ->> 'role';
    v_workshop_name := NEW.raw_user_meta_data ->> 'workshop_name';
    v_address       := NEW.raw_user_meta_data ->> 'address';
    v_lat           := NEW.raw_user_meta_data ->> 'latitude';
    v_lon           := NEW.raw_user_meta_data ->> 'longitude';

    -- ========================================================================
    -- Mandatory role: no default, no silent car_owner fallback.
    -- ========================================================================
    if v_role_text is null or btrim(v_role_text) = '' then
        raise exception 'MISSING_ROLE: a role (car_owner or provider) is required at signup';
    end if;

    if v_role_text not in ('car_owner', 'provider') then
        raise exception 'INVALID_ROLE: role % is not a valid signup role (expected car_owner or provider)', v_role_text;
    end if;

    v_role := v_role_text::public.user_role;

    -- Generate email if not provided
    if NEW.email is null or NEW.email = '' then
        v_email := coalesce(v_phone_number, '') || '@mahwar.app';
    else
        v_email := NEW.email;
    end if;

    -- ========================================================================
    -- Provider-required fields (server-side, before any insert).
    -- ========================================================================
    if v_role = 'provider'::public.user_role then
        if v_national_id is null or btrim(v_national_id) = '' then
            raise exception 'MISSING_NATIONAL_ID: national ID is required for provider accounts';
        end if;

        if v_workshop_name is null or btrim(v_workshop_name) = '' then
            raise exception 'MISSING_WORKSHOP_NAME: workshop name is required for provider accounts';
        end if;

        if v_address is null or btrim(v_address) = '' then
            raise exception 'MISSING_ADDRESS: workshop address is required for provider accounts';
        end if;

        if v_lat is null or btrim(v_lat) = '' then
            raise exception 'MISSING_LATITUDE: latitude location is required for provider accounts';
        end if;

        if v_lon is null or btrim(v_lon) = '' then
            raise exception 'MISSING_LONGITUDE: longitude location is required for provider accounts';
        end if;

        begin
            v_lat_num := v_lat::double precision;
            v_lon_num := v_lon::double precision;
        exception when others then
            raise exception 'INVALID_LOCATION: latitude/longitude must be numeric';
        end;

        if v_lat_num < -90 or v_lat_num > 90 then
            raise exception 'INVALID_LATITUDE: latitude must be between -90 and 90';
        end if;

        if v_lon_num < -180 or v_lon_num > 180 then
            raise exception 'INVALID_LONGITUDE: longitude must be between -180 and 180';
        end if;

        v_specializations := array(
            select btrim(x)
            from jsonb_array_elements_text(
                coalesce(NEW.raw_user_meta_data -> 'specializations', '[]'::jsonb)
            ) as t(x)
            where btrim(x) <> ''
        );

        if array_length(v_specializations, 1) is null then
            raise exception 'MISSING_SPECIALIZATION: at least one specialization is required for provider accounts';
        end if;
    end if;

    -- ========================================================================
    -- Account-exists checks (phone, then national id).
    -- Only the existing ROLE is surfaced; never the phone / national id / email.
    -- ========================================================================
    if v_phone_number is not null and v_phone_number != '' then
        select p.role::text into v_existing_role
        from public.profiles p
        where p.phone_number = v_phone_number
           or public.normalize_phone(p.phone_number) = v_phone_number
        limit 1;

        if v_existing_role is not null then
            raise exception 'ACCOUNT_EXISTS_AS:%', v_existing_role;
        end if;
    end if;

    if v_national_id is not null and v_national_id != '' then
        select p.role::text into v_existing_role
        from public.profiles p
        where p.national_id = v_national_id
        limit 1;

        if v_existing_role is not null then
            raise exception 'ACCOUNT_EXISTS_AS:%', v_existing_role;
        end if;
    end if;

    -- Map legacy support_scope values to the DB enum (robust against bad input)
    v_support_scope := case
        when lower(coalesce(NEW.raw_user_meta_data ->> 'support_scope', 'both')) = 'emergency' then 'emergency'::public.support_scope
        when lower(coalesce(NEW.raw_user_meta_data ->> 'support_scope', 'both')) = 'roadside' then 'emergency'::public.support_scope
        when lower(coalesce(NEW.raw_user_meta_data ->> 'support_scope', 'both')) = 'on_site' then 'on_site'::public.support_scope
        when lower(coalesce(NEW.raw_user_meta_data ->> 'support_scope', 'both')) = 'onsite' then 'on_site'::public.support_scope
        else 'both'::public.support_scope
    end;

    -- Create profile
    insert into public.profiles (
        id, email, full_name, phone_number, national_id, role, created_at, updated_at
    ) values (
        NEW.id,
        v_email,
        coalesce(v_full_name, split_part(v_email, '@', 1), 'مستخدم'),
        v_phone_number,
        case when v_national_id = '' then null else v_national_id end,
        v_role,
        now(),
        now()
    );

    -- Create provider record if role is provider
    if v_role = 'provider'::public.user_role then
        insert into public.providers (
            id, workshop_name, address, latitude, longitude, support_scope,
            has_vehicle, vehicle_specs, created_at
        ) values (
            NEW.id,
            v_workshop_name,
            v_address,
            v_lat_num,
            v_lon_num,
            v_support_scope,
            coalesce((NEW.raw_user_meta_data ->> 'has_vehicle')::boolean, false),
            NEW.raw_user_meta_data ->> 'vehicle_specs',
            now()
        );
    end if;

    -- Create car_details if role is car_owner
    if v_role = 'car_owner'::public.user_role then
        insert into public.car_details (
            user_id, make, model, year, plate_number, color, created_at
        ) values (
            NEW.id,
            NEW.raw_user_meta_data ->> 'car_make',
            NEW.raw_user_meta_data ->> 'car_model',
            nullif(NEW.raw_user_meta_data ->> 'car_year', '')::integer,
            NEW.raw_user_meta_data ->> 'car_plate_number',
            NEW.raw_user_meta_data ->> 'car_color',
            now()
        );
    end if;

    -- Create provider_car_details if role is provider and has_vehicle
    if v_role = 'provider'::public.user_role then
        v_has_vehicle := coalesce((NEW.raw_user_meta_data ->> 'has_vehicle')::boolean, false);
        if v_has_vehicle is true then
            insert into public.provider_car_details (
                provider_id, make, model, year, plate_number, color, created_at
            ) values (
                NEW.id,
                NEW.raw_user_meta_data ->> 'vehicle_make',
                NEW.raw_user_meta_data ->> 'vehicle_model',
                nullif(NEW.raw_user_meta_data ->> 'vehicle_year', '')::integer,
                NEW.raw_user_meta_data ->> 'vehicle_plate',
                NEW.raw_user_meta_data ->> 'vehicle_color',
                now()
            );
        end if;
    end if;

    -- Create provider specializations (guaranteed non-empty for providers above)
    if v_role = 'provider'::public.user_role then
        insert into public.provider_specializations (provider_id, service_type_id)
        select NEW.id, s
        from unnest(v_specializations) as s;
    end if;

    return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Pre/post audit: list any phone / national id / email shared across roles.
-- Expected: zero rows (all three columns are UNIQUE).
-- -----------------------------------------------------------------------------
-- select 'phone' kind, phone_number value, array_agg(distinct role::text) roles, count(*)
-- from public.profiles where phone_number is not null and phone_number <> ''
-- group by phone_number having count(distinct role) > 1
-- union all
-- select 'national_id', national_id, array_agg(distinct role::text), count(*)
-- from public.profiles where national_id is not null and national_id <> ''
-- group by national_id having count(distinct role) > 1
-- union all
-- select 'email', lower(email), array_agg(distinct role::text), count(*)
-- from public.profiles where email is not null and email <> ''
-- group by lower(email) having count(distinct role) > 1;
