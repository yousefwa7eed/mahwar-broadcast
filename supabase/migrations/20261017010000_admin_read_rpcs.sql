-- =============================================================================
-- Phase 5A (read-only admin layer) -- admin READ RPCs + dashboard signup path
--
-- Provided here, all guarded FIRST by public.is_admin() (admins row AND aal2):
--   * admin_session_state()      -- login-flow helper (NOT admin-gated, returns
--                                  only the CALLER's own state) so the dashboard
--                                  knows whether to run TOTP enrollment.
--   * admin_dashboard_counts()   -- users total/24h/7d, roles, online providers,
--                                  orders by status, notifications.
--   * admin_list_users(...)      -- paginated searchable users list. Phone &
--                                  national id are MASKED. Full national id is
--                                  NEVER returned except by reveal RPC.
--   * admin_get_user(uuid)       -- single-user deep detail as jsonb (profile,
--                                  auth entry, cars, provider info, orders,
--                                  ratings, recent SMS, audit entries).
--   * admin_reveal_national_id(uuid, reason) -- audited plaintext reveal.
--                                  REQUIRES a non-empty reason.
--   * admin_export_users(...)    -- audited export rows (masked national id,
--                                  hard cap 5000 rows).
--
-- Every admin-gated function:
--   * SECURITY DEFINER with search_path='' (all references fully qualified)
--   * raises 'ADMIN_ONLY' before touching any data when not admin
--   * never writes unless admin (fail-closed)
--   * revoked from public/anon; execute granted to authenticated (+service_role
--     for future automated reporting; is_admin() still gates the actual work).
--
-- Signup path for the admin account (email, from the dashboard site only):
--   handle_new_user() keeps its ENTIRE current logic (fetched live via
--   pg_get_functiondef on 2026-10-17) and gains ONE narrow early bypass:
--   when raw_user_meta_data has signup_source = 'admin_dashboard', the account
--   is created auth-only (NO public.profiles row => never appears in any app
--   list) and is pinned into unverified_account_exemptions so the
--   abandoned-signup purge cron can never delete it. Every other signup
--   behaves exactly as before.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. handle_new_user: EXACT current definition + admin-dashboard early bypass.
--    Only the bypass block is new; everything below it is the live original.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
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
    -- ========================================================================
    -- Admin dashboard signup bypass (phase 5A, 2026-10-17):
    -- signup_source = 'admin_dashboard' creates an auth-only account:
    --   * NO public.profiles row => never appears in any app user list.
    --   * pinned into unverified_account_exemptions so the abandoned-signup
    --     purge cron can never delete it.
    -- Behavior for every other signup is unchanged.
    -- ========================================================================
    if NEW.raw_user_meta_data ->> 'signup_source' = 'admin_dashboard' then
        insert into public.unverified_account_exemptions (user_id, reason)
        values (NEW.id, 'admin dashboard control account')
        on conflict (user_id) do nothing;
        return new;
    end if;

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
    -- Phone surfaces ONLY the existing role; national ID stays generic.
    -- Neither branch echoes the submitted value.
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

    -- National id compared in the same canonical form as the unique index
    -- profiles_national_id_canonical_key, guarded like its predicate.
    if v_national_id is not null and v_national_id <> '' then
        if exists (
            select 1 from public.profiles
            where translate(national_id, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'::text, '01234567890123456789'::text) =
                  translate(v_national_id, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'::text, '01234567890123456789'::text)
        ) then
            raise exception 'NATIONAL_ID_EXISTS: national ID is already registered';
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
$function$;

-- ---------------------------------------------------------------------------
-- 2. admin_session_state(): login-flow helper. Returns ONLY the caller's own
--    state (self-info), never other users' data. Safe pre-TOTP: it tells the
--    dashboard whether this email is on the admin list and whether a verified
--    TOTP factor exists, so the UI can route to enrollment.
-- ---------------------------------------------------------------------------
create or replace function public.admin_session_state()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'user_id',      auth.uid(),
    'is_admin_row', exists (
                      select 1 from public.admins a where a.user_id = auth.uid()
                    ),
    'aal',          coalesce(auth.jwt() ->> 'aal', 'aal1'),
    'mfa_enrolled', exists (
                      select 1
                      from auth.mfa_factors f
                      where f.user_id = auth.uid()
                        and f.status = 'verified'
                    )
  );
$$;

revoke all on function public.admin_session_state() from public;
revoke all on function public.admin_session_state() from anon;
grant execute on function public.admin_session_state() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Shared admin gate (internal): every admin RPC starts with this.
-- ---------------------------------------------------------------------------
create or replace function public.assert_admin()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not coalesce(public.is_admin(), false) then
    raise exception 'ADMIN_ONLY: admin email + TOTP (aal2) required';
  end if;
end;
$$;

revoke all on function public.assert_admin() from public;
revoke all on function public.assert_admin() from anon;
grant execute on function public.assert_admin() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. admin_dashboard_counts(): the top panel numbers.
-- ---------------------------------------------------------------------------
create or replace function public.admin_dashboard_counts()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.assert_admin();

  return jsonb_build_object(
    'users_total',    (select count(*) from public.profiles),
    'users_owners',   (select count(*) from public.profiles where role = 'car_owner'),
    'users_providers',(select count(*) from public.profiles where role = 'provider'),
    'providers_online',(select count(*) from public.providers where is_online is true),
    'users_created_24h',(select count(*) from public.profiles
                         where created_at > now() - interval '24 hours'),
    'users_created_7d', (select count(*) from public.profiles
                         where created_at > now() - interval '7 days'),
    'users_phone_verified', (select count(*) from public.profiles
                             where phone_verified_at is not null),
    'users_phone_unverified',(select count(*) from public.profiles
                              where phone_verified_at is null),
    'orders_total',      (select count(*) from public.orders),
    'orders_created_24h',(select count(*) from public.orders
                          where created_at > now() - interval '24 hours'),
    'orders_created_7d', (select count(*) from public.orders
                          where created_at > now() - interval '7 days'),
    'orders_by_status',  (select coalesce(jsonb_object_agg(status::text, cnt), '{}'::jsonb)
                          from (select status, count(*) as cnt
                                from public.orders group by status) s),
    'notifications_total',(select count(*) from public.notifications)
  );
end;
$$;

revoke all on function public.admin_dashboard_counts() from public;
revoke all on function public.admin_dashboard_counts() from anon;
grant execute on function public.admin_dashboard_counts() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. admin_list_users(): paginated + searchable. Masked columns only.
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_users(
  p_page      int  default 1,
  p_page_size int  default 25,
  p_search    text default null,
  p_role      text default null
)
returns table (
  user_id            uuid,
  full_name          text,
  phone_number       text,
  role               text,
  workshop_name      text,
  is_online          boolean,
  phone_verified     boolean,
  has_national_id    boolean,
  national_id_last4  text,
  orders_as_owner    int,
  orders_as_provider int,
  created_at         timestamptz,
  total_count        bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_page   int := greatest(coalesce(p_page, 1), 1);
  v_size   int := least(greatest(coalesce(p_page_size, 25), 1), 100);
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_digits text;
  v_role   public.user_role;
begin
  perform public.assert_admin();

  if v_search is not null then
    v_digits := nullif(regexp_replace(v_search, '\D', '', 'g'), '');
  end if;

  v_role := case
    when coalesce(p_role, '') in ('car_owner', 'provider')
    then p_role::public.user_role
  end;

  return query
  with base as (
    select
      pr.id                                   as uid,
      pr.full_name,
      pr.phone_number,
      pr.role::text                           as role_text,
      pw.workshop_name,
      pw.is_online,
      (pr.phone_verified_at is not null)      as phone_verified,
      (pr.national_id is not null
        and btrim(pr.national_id) <> '')      as has_nid,
      case
        when pr.national_id is not null and btrim(pr.national_id) <> ''
        then right(regexp_replace(pr.national_id, '\D', '', 'g'), 4)
      end                                     as nid_last4,
      pr.created_at,
      count(*) over ()                        as total
    from public.profiles pr
    left join public.providers pw on pw.id = pr.id
    where (v_role is null or pr.role = v_role)
      and (
        v_search is null
        or pr.full_name  ilike '%' || v_search || '%'
        or pr.email      ilike '%' || v_search || '%'
        or pw.workshop_name ilike '%' || v_search || '%'
        or (v_digits is not null
            and (regexp_replace(pr.phone_number, '\D', '', 'g') like '%' || v_digits || '%'
                 or (pr.national_id is not null
                     and translate(pr.national_id,
                           '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'::text,
                           '01234567890123456789'::text)
                          like '%' || v_digits || '%')))
      )
  )
  select
    b.uid,
    b.full_name,
    b.phone_number,
    b.role_text,
    b.workshop_name,
    b.is_online,
    b.phone_verified,
    b.has_nid,
    b.nid_last4,
    coalesce((select count(*) from public.orders o where o.car_owner_id = b.uid), 0)::int,
    coalesce((select count(*) from public.orders o where o.provider_id = b.uid), 0)::int,
    b.created_at,
    b.total
  from base b
  order by b.created_at desc, b.uid
  limit v_size
  offset (v_page - 1) * v_size;
end;
$$;

revoke all on function public.admin_list_users(int, int, text, text) from public;
revoke all on function public.admin_list_users(int, int, text, text) from anon;
grant execute on function public.admin_list_users(int, int, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. admin_get_user(): one user's deep detail. National id masked (last 4).
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_user(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.assert_admin();

  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'USER_NOT_FOUND';
  end if;

  return jsonb_build_object(
    'profile', (
      select jsonb_build_object(
        'id',              pr.id,
        'full_name',       pr.full_name,
        'phone_number',    pr.phone_number,
        'email',           pr.email,
        'role',            pr.role::text,
        'language',        pr.language,
        'avatar_id',       pr.avatar_id,
        'created_at',      pr.created_at,
        'updated_at',      pr.updated_at,
        'phone_verified_at', pr.phone_verified_at,
        'has_national_id', (pr.national_id is not null and btrim(pr.national_id) <> ''),
        'national_id_last4', case
          when pr.national_id is not null and btrim(pr.national_id) <> ''
          then right(regexp_replace(pr.national_id, '\D', '', 'g'), 4)
        end
      )
      from public.profiles pr where pr.id = p_user_id
    ),
    'auth', (
      select jsonb_build_object(
        'email',         u.email,
        'last_sign_in_at', u.last_sign_in_at,
        'created_at',    u.created_at,
        'banned_until',  u.banned_until
      )
      from auth.users u where u.id = p_user_id
    ),
    'cars', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id, 'make', c.make, 'model', c.model, 'year', c.year,
        'plate_number', c.plate_number, 'color', c.color, 'created_at', c.created_at
      )), '[]'::jsonb)
      from public.car_details c where c.user_id = p_user_id
    ),
    'provider', (
      select
        case when count(*) = 0 then null else jsonb_build_object(
          'workshop_name',    max(pw.workshop_name),
          'address',          max(pw.address),
          'latitude',         max(pw.latitude),
          'longitude',        max(pw.longitude),
          'support_scope',    max(pw.support_scope::text),
          'has_vehicle',      max(pw.has_vehicle),
          'vehicle_specs',    max(pw.vehicle_specs),
          'is_online',        max(pw.is_online),
          'location_updated_at', max(pw.location_updated_at),
          'created_at',       max(pw.created_at)
        ) end
      from public.providers pw where pw.id = p_user_id
    ),
    'specializations', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', st.id, 'name_ar', st.name_ar, 'name_en', st.name_en
      )), '[]'::jsonb)
      from public.provider_specializations ps
      join public.service_types st on st.id = ps.service_type_id
      where ps.provider_id = p_user_id
    ),
    'orders_as_owner', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id, 'status', o.status::text,
        'service_type', st.name_ar,
        'offered_price', o.offered_price,
        'created_at', o.created_at, 'updated_at', o.updated_at
      )), '[]'::jsonb)
      from (
        select o.*, row_number() over (order by o.created_at desc) as rn
        from public.orders o where o.car_owner_id = p_user_id
      ) o
      left join public.service_types st on st.id = o.service_type_id
      where o.rn <= 20
    ),
    'orders_as_provider', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id, 'status', o.status::text,
        'service_type', st.name_ar,
        'offered_price', o.offered_price,
        'created_at', o.created_at, 'updated_at', o.updated_at
      )), '[]'::jsonb)
      from (
        select o.*, row_number() over (order by o.created_at desc) as rn
        from public.orders o where o.provider_id = p_user_id
      ) o
      left join public.service_types st on st.id = o.service_type_id
      where o.rn <= 20
    ),
    'ratings_received', (
      select jsonb_build_object(
        'avg', round(avg(rating)::numeric, 2),
        'count', count(*)
      )
      from public.ratings where provider_id = p_user_id
    ),
    'ratings_given', (
      select jsonb_build_object(
        'avg', round(avg(rating)::numeric, 2),
        'count', count(*)
      )
      from public.ratings where user_id = p_user_id
    ),
    'notifications_count', (
      select count(*) from public.notifications where user_id = p_user_id
    ),
    'sms_recent', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'phone_local', s.phone_local, 'result', s.result,
        'created_at', s.created_at
      )), '[]'::jsonb)
      from (
        select s.*, row_number() over (order by s.created_at desc) as rn
        from public.sms_send_logs s where s.user_id = p_user_id
      ) s
      where s.rn <= 10
    ),
    'audit_entries', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', a.id, 'action', a.action, 'details', a.details,
        'created_at', a.created_at,
        'admin_name', pr.full_name
      ) order by a.created_at desc), '[]'::jsonb)
      from (
        select a.*, row_number() over (order by a.created_at desc) as rn
        from public.admin_audit_log a where a.target_user_id = p_user_id
      ) a
      left join public.profiles pr on pr.id = a.admin_id
      where a.rn <= 25
    )
  );
end;
$$;

revoke all on function public.admin_get_user(uuid) from public;
revoke all on function public.admin_get_user(uuid) from anon;
grant execute on function public.admin_get_user(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7. admin_reveal_national_id(): audited plaintext reveal. Reason REQUIRED.
-- ---------------------------------------------------------------------------
create or replace function public.admin_reveal_national_id(
  p_user_id uuid,
  p_reason  text
)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_nid    text;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  perform public.assert_admin();

  if length(v_reason) < 5 then
    raise exception 'REASON_REQUIRED: a reason of at least 5 characters is required to reveal a national ID';
  end if;

  select pr.national_id into v_nid
  from public.profiles pr
  where pr.id = p_user_id;

  if not found then
    raise exception 'USER_NOT_FOUND';
  end if;

  if v_nid is null or btrim(v_nid) = '' then
    raise exception 'NO_NATIONAL_ID: this user has no national ID on file';
  end if;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (
    auth.uid(),
    'reveal_national_id',
    p_user_id,
    jsonb_build_object('reason', v_reason)
  );

  return v_nid;
end;
$$;

revoke all on function public.admin_reveal_national_id(uuid, text) from public;
revoke all on function public.admin_reveal_national_id(uuid, text) from anon;
grant execute on function public.admin_reveal_national_id(uuid, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 8. admin_export_users(): audited export source rows (masked national id,
--    hard cap 5000). The dashboard builds the CSV client-side.
-- ---------------------------------------------------------------------------
create or replace function public.admin_export_users(
  p_search text default null,
  p_role   text default null
)
returns table (
  full_name          text,
  phone_number       text,
  email              text,
  role               text,
  workshop_name      text,
  is_online          boolean,
  phone_verified     boolean,
  has_national_id    boolean,
  national_id_last4  text,
  orders_as_owner    int,
  orders_as_provider int,
  created_at         timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_digits text;
  v_role   public.user_role;
  v_marked bigint;
begin
  perform public.assert_admin();

  if v_search is not null then
    v_digits := nullif(regexp_replace(v_search, '\D', '', 'g'), '');
  end if;

  v_role := case
    when coalesce(p_role, '') in ('car_owner', 'provider')
    then p_role::public.user_role
  end;

  with base as (
    select
      pr.id                                   as uid,
      pr.full_name,
      pr.phone_number,
      pr.email,
      pr.role::text                           as role_text,
      pw.workshop_name,
      pw.is_online,
      (pr.phone_verified_at is not null)      as phone_verified,
      (pr.national_id is not null
        and btrim(pr.national_id) <> '')      as has_nid,
      case
        when pr.national_id is not null and btrim(pr.national_id) <> ''
        then right(regexp_replace(pr.national_id, '\D', '', 'g'), 4)
      end                                     as nid_last4,
      pr.created_at,
      count(*) over ()                        as total
    from public.profiles pr
    left join public.providers pw on pw.id = pr.id
    where (v_role is null or pr.role = v_role)
      and (
        v_search is null
        or pr.full_name  ilike '%' || v_search || '%'
        or pr.email      ilike '%' || v_search || '%'
        or pw.workshop_name ilike '%' || v_search || '%'
        or (v_digits is not null
            and (regexp_replace(pr.phone_number, '\D', '', 'g') like '%' || v_digits || '%'
                 or (pr.national_id is not null
                     and translate(pr.national_id,
                           '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'::text,
                           '01234567890123456789'::text)
                          like '%' || v_digits || '%')))
      )
  )
  select
    b.full_name,
    b.phone_number,
    b.email,
    b.role_text,
    b.workshop_name,
    b.is_online,
    b.phone_verified,
    b.has_nid,
    b.nid_last4,
    coalesce((select count(*) from public.orders o where o.car_owner_id = b.uid), 0)::int,
    coalesce((select count(*) from public.orders o where o.provider_id = b.uid), 0)::int,
    b.created_at
  from base b
  order by b.created_at desc
  limit 5000;

  get diagnostics v_marked = row_count;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (
    auth.uid(),
    'export_users_csv',
    null,
    jsonb_build_object(
      'rows_returned', v_marked,
      'search',        v_search,
      'role',          p_role
    )
  );
end;
$$;

revoke all on function public.admin_export_users(text, text) from public;
revoke all on function public.admin_export_users(text, text) from anon;
grant execute on function public.admin_export_users(text, text) to authenticated, service_role;

-- =============================================================================
-- Verify after applying (read-only):
--   select routine_name from information_schema.routines
--     where routine_schema='public' and routine_name like 'admin\_%';
--     -- expect: session_state (6 funcs total)
--   select has_function_privilege('anon','public.admin_dashboard_counts()','execute');
--     -- expect false
--   -- Non-admin execution test (MCP/SQL editor runs as postgres = no aal2):
--   select public.admin_dashboard_counts();
--     -- expect error 'ADMIN_ONLY...'
-- =============================================================================
