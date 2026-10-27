-- ترحيل بيانات السيارات: car_details → vehicles المرتبطة بالكتالوج.
-- مطبَّق على القاعدة الحيّة (applied as 20261027153726).
--
-- ما يفعله هذا الملف بالترتيب:
--   1) إنشاء جدول vehicles + قيود الملكية/الحماية + triggers (افتراضي واحد، تحقق السنة واللوحة).
--   2) ترحيل صفوف car_details القابلة للمطابقة إلى vehicles.
--   3) إضافة لقطات السيارة إلى orders (المعرّفات + النصوص) مع الإبقاء على car_make/model/year.
--   4) تحديث الدوال: handle_new_user, create_order_for_provider, admin_get_user,
--      cleanup_user_data, delete_user_account، وحذف update_pending_order غير المستخدمة.
--   5) حذف car_details بعد الترحيل.

begin;

-- ============================================================================
-- 1) vehicles
-- ============================================================================
create table if not exists public.vehicles (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  trim_id        text not null references public.vehicle_trims(id),
  model_year     integer not null check (model_year between 1950 and 2100),
  color_id       text references public.vehicle_colors(id),
  plate_letters  text,
  plate_digits   text,
  is_default     boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint vehicles_plate_pair check (
    (plate_letters is null and plate_digits is null)
    or (plate_letters is not null and plate_digits is not null)
  )
);

create index if not exists vehicles_user_idx on public.vehicles(user_id);
create unique index if not exists vehicles_one_default_idx
  on public.vehicles(user_id) where is_default;

alter table public.vehicles enable row level security;
alter table public.vehicles force row level security;

do $$ begin
  create policy "vehicles_select_own" on public.vehicles
    for select to authenticated using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "vehicles_insert_own" on public.vehicles
    for insert to authenticated with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "vehicles_update_own" on public.vehicles
    for update to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "vehicles_delete_own" on public.vehicles
    for delete to authenticated using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

revoke all on public.vehicles from anon;
grant select, insert, update, delete on public.vehicles to authenticated;
grant all on public.vehicles to service_role;

-- ----------------------------------------------------------------------------
-- Trigger: single default vehicle + validation against the catalog.
-- ----------------------------------------------------------------------------
create or replace function public.vehicles_before_write()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_year_from int;
  v_year_to   int;
  v_has_default boolean;
begin
  select g.year_from, g.year_to
    into v_year_from, v_year_to
  from public.vehicle_trims t
  join public.vehicle_generations g on g.id = t.generation_id
  where t.id = new.trim_id;

  if not found then
    raise exception 'VEHICLE_TRIM_NOT_FOUND';
  end if;

  if new.model_year < v_year_from
     or (v_year_to is not null and new.model_year > v_year_to) then
    raise exception 'INVALID_MODEL_YEAR';
  end if;

  if new.color_id is not null
     and not exists (select 1 from public.vehicle_colors c where c.id = new.color_id) then
    raise exception 'VEHICLE_COLOR_NOT_FOUND';
  end if;

  if new.plate_letters is not null or new.plate_digits is not null then
    new.plate_letters := btrim(new.plate_letters);
    new.plate_digits  := btrim(new.plate_digits);
    if new.plate_letters is null or new.plate_digits is null then
      raise exception 'INVALID_PLATE';
    end if;
    -- نفس قائمة الحروف الرسمية في PlateUtils (17 حرفاً) — لا نقبل أي حرف
    -- عربي آخر حتى لا تختلف القاعدة عن العميل.
    if new.plate_letters !~ '^[أبجدرسصطعقكلمنهوى]{3}$'
       or new.plate_digits !~ '^[0-9]{3,4}$' then
      raise exception 'INVALID_PLATE';
    end if;
  end if;

  if tg_op = 'INSERT' then
    if new.is_default then
      update public.vehicles
         set is_default = false
       where user_id = new.user_id and is_default;
    else
      select exists (
        select 1 from public.vehicles
        where user_id = new.user_id and is_default
      ) into v_has_default;
      if not v_has_default then
        new.is_default := true;
      end if;
    end if;
  elsif new.is_default and not old.is_default then
    update public.vehicles
       set is_default = false
     where user_id = new.user_id and id <> new.id and is_default;
  end if;

  new.updated_at := now();
  return new;
end;
$function$;

drop trigger if exists trg_vehicles_before_write on public.vehicles;
create trigger trg_vehicles_before_write
  before insert or update on public.vehicles
  for each row execute function public.vehicles_before_write();

-- عند حذف السيارة الافتراضية نرقّي أقدم سيارة متبقية.
create or replace function public.vehicles_after_delete()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if old.is_default then
    update public.vehicles
       set is_default = true
     where id = (
       select id from public.vehicles
        where user_id = old.user_id
        order by created_at, id
        limit 1
     );
  end if;
  return old;
end;
$function$;

drop trigger if exists trg_vehicles_after_delete on public.vehicles;
create trigger trg_vehicles_after_delete
  after delete on public.vehicles
  for each row execute function public.vehicles_after_delete();

-- ============================================================================
-- 2) Backfill from car_details (best-effort exact/alias matching).
--    Old free-text plate is split only when it matches the Egyptian pattern.
-- ============================================================================
insert into public.vehicles (
  user_id, trim_id, model_year, color_id,
  plate_letters, plate_digits, is_default, created_at
)
select
  c.user_id,
  t.id,
  c.year,
  col.id,
  case when c.plate_number ~ '^[^0-9]{3}[0-9]{3,4}$' then left(c.plate_number, 3) end,
  case when c.plate_number ~ '^[^0-9]{3}[0-9]{3,4}$' then right(c.plate_number, length(c.plate_number) - 3) end,
  false,
  coalesce(c.created_at, now())
from public.car_details c
join public.profiles p on p.id = c.user_id
left join public.vehicle_colors col
  on col.name_ar = c.color or col.name_en ilike c.color
join lateral (
  select t.id
  from public.vehicle_trims t
  join public.vehicle_generations g on g.id = t.generation_id
  join public.vehicle_models m on m.id = g.model_id
  join public.vehicle_brands b on b.id = m.brand_id
  where c.year between g.year_from and coalesce(g.year_to, 2100)
    and (
      b.name_ar = c.make
      or b.name_en ilike c.make
      or (b.id = 'mercedes' and c.make like 'مرسيدس%')
    )
    and (
      m.name_ar = c.model
      or m.name_en ilike c.model
      or (b.id = 'mercedes' and m.id = 'mercedes-c-class'
          and c.model in ('سي كلاس', 'C Class', 'C-Class'))
      or (b.id = 'mercedes' and m.id = 'mercedes-glc'
          and c.model in ('جي إل سي', 'GLC'))
    )
  order by t.sort_order, t.id
  limit 1
) t on true
where not exists (
  select 1 from public.vehicles v where v.user_id = c.user_id
);

-- بعد الترحيل: سيارة افتراضية واحدة لكل مالك (الأقدم)، دون الاعتماد على ترتيب
-- الـtrigger داخل نفس عبارة الـINSERT.
update public.vehicles v
   set is_default = true
 where v.id in (
   select distinct on (user_id) id
   from public.vehicles
   order by user_id, created_at, id
 )
   and not exists (
     select 1 from public.vehicles d
      where d.user_id = v.user_id and d.is_default
   );

-- ============================================================================
-- 3) Order snapshots
-- ============================================================================
alter table public.orders
  add column if not exists vehicle_id    uuid references public.vehicles(id) on delete set null,
  add column if not exists car_brand_id  text references public.vehicle_brands(id) on delete set null,
  add column if not exists car_trim_id   text references public.vehicle_trims(id) on delete set null,
  add column if not exists car_trim      text,
  add column if not exists car_color_id  text references public.vehicle_colors(id) on delete set null,
  add column if not exists car_color     text,
  add column if not exists car_plate     text;

create index if not exists orders_vehicle_idx on public.orders(vehicle_id);

-- ============================================================================
-- 4) Functions
-- ============================================================================

-- 4a) create_order_for_provider — p_vehicle_id replaces the free-text car args,
--     and the phone params are gone entirely (phone is never client-supplied).
drop function if exists public.create_order_for_provider(
  uuid, text, text, text, integer, double precision, double precision,
  text, text, boolean, boolean, text, text, text[]
);

create or replace function public.create_order_for_provider(
  p_provider_id      uuid,
  p_service_type_id  text,
  p_vehicle_id       uuid,
  p_latitude         double precision,
  p_longitude        double precision,
  p_notes            text,
  p_auto_cancel      boolean,
  p_address_text     text default null,
  p_currency         text default 'EGP',
  p_attachments      text[] default null
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_owner      uuid := auth.uid();
  v_id         uuid;
  v_url        text;
  v_brand_id   text;
  v_brand_name text;
  v_model_name text;
  v_trim_id    text;
  v_trim_name  text;
  v_color_id   text;
  v_color_name text;
  v_year       integer;
  v_plate      text;
begin
  if v_owner is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if not public.get_my_phone_verified() then
    raise exception 'PHONE_NOT_VERIFIED';
  end if;
  if p_provider_id is null or p_provider_id = v_owner then
    raise exception 'PROVIDER_UNAVAILABLE';
  end if;
  if not exists (select 1 from public.providers pr where pr.id = p_provider_id) then
    raise exception 'PROVIDER_UNAVAILABLE';
  end if;
  if not public.is_provider_eligible_for_order(p_provider_id, p_service_type_id, p_latitude, p_longitude) then
    raise exception 'PROVIDER_UNAVAILABLE';
  end if;

  select b.id, b.name_ar, m.name_ar, t.id, t.name_ar,
         v.color_id, c.name_ar, v.model_year,
         nullif(concat_ws(' ', v.plate_letters, v.plate_digits), '')
    into v_brand_id, v_brand_name, v_model_name, v_trim_id, v_trim_name,
         v_color_id, v_color_name, v_year, v_plate
  from public.vehicles v
  join public.vehicle_trims t on t.id = v.trim_id
  join public.vehicle_generations g on g.id = t.generation_id
  join public.vehicle_models m on m.id = g.model_id
  join public.vehicle_brands b on b.id = m.brand_id
  left join public.vehicle_colors c on c.id = v.color_id
  where v.id = p_vehicle_id and v.user_id = v_owner;

  if not found then
    raise exception 'VEHICLE_NOT_FOUND';
  end if;

  if coalesce(array_length(p_attachments, 1), 0) > 10 then
    raise exception 'TOO_MANY_ATTACHMENTS';
  end if;
  if p_attachments is not null then
    foreach v_url in array p_attachments loop
      if not public.is_valid_order_attachment(v_url, v_owner) then
        raise exception 'INVALID_ATTACHMENT_URL';
      end if;
    end loop;
  end if;

  insert into public.orders (
    car_owner_id, provider_id, service_type_id, status,
    car_make, car_model, car_year,
    vehicle_id, car_brand_id, car_trim_id, car_trim,
    car_color_id, car_color, car_plate,
    latitude, longitude, address_text, notes,
    owner_phone, currency, auto_cancel, share_phone, attachments
  )
  values (
    v_owner, p_provider_id, p_service_type_id, 'pending',
    v_brand_name, v_model_name, v_year,
    p_vehicle_id, v_brand_id, v_trim_id, v_trim_name,
    v_color_id, v_color_name, v_plate,
    p_latitude, p_longitude, p_address_text, p_notes,
    null, coalesce(p_currency, 'EGP'), p_auto_cancel, false, p_attachments
  )
  returning id into v_id;

  if p_auto_cancel then
    update public.orders
       set respond_deadline = now() + interval '5 minutes'
     where id = v_id;
  end if;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    p_provider_id, v_id, 'new_order',
    jsonb_build_object(
      'service_type_id', p_service_type_id,
      'service_name', (select st.name_ar from public.service_types st where st.id = p_service_type_id)
    )
  );

  return v_id;
end;
$function$;

revoke all on function public.create_order_for_provider(
  uuid, text, uuid, double precision, double precision, text, boolean, text, text, text[]
) from public, anon;
grant execute on function public.create_order_for_provider(
  uuid, text, uuid, double precision, double precision, text, boolean, text, text, text[]
) to authenticated, service_role;

-- 4b) admin_get_user — same JSON keys for the dashboard, now backed by vehicles.
create or replace function public.admin_get_user(p_user_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
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
        'national_id',     pr.national_id,
        'role',            pr.role::text,
        'language',        pr.language,
        'avatar_id',       pr.avatar_id,
        'created_at',      pr.created_at,
        'updated_at',      pr.updated_at,
        'phone_verified_at', pr.phone_verified_at
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
        'id', v.id,
        'make', b.name_ar,
        'model', m.name_ar,
        'year', v.model_year,
        'plate_number', nullif(concat_ws(' ', v.plate_letters, v.plate_digits), ''),
        'color', c.name_ar,
        'trim', t.name_ar,
        'brand_id', b.id,
        'created_at', v.created_at
      ) order by v.created_at), '[]'::jsonb)
      from public.vehicles v
      join public.vehicle_trims t on t.id = v.trim_id
      join public.vehicle_generations g on g.id = t.generation_id
      join public.vehicle_models m on m.id = g.model_id
      join public.vehicle_brands b on b.id = m.brand_id
      left join public.vehicle_colors c on c.id = v.color_id
      where v.user_id = p_user_id
    ),
    'provider', (
      select
        case when count(*) = 0 then null else jsonb_build_object(
          'workshop_name',    max(pw.workshop_name),
          'address',          max(pw.address),
          'latitude',         max(pw.latitude),
          'longitude',        max(pw.longitude),
          'support_scope',    max(pw.support_scope::text),
          'has_vehicle',      coalesce(bool_or(pw.has_vehicle), false),
          'vehicle_specs',    max(pw.vehicle_specs),
          'is_online',        coalesce(bool_or(pw.is_online), false),
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
$function$;

-- 4c) cleanup_user_data
create or replace function public.cleanup_user_data(p_user_id uuid default auth.uid())
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  delete from public.notifications where user_id = p_user_id;
  delete from public.orders where car_owner_id = p_user_id or provider_id = p_user_id;
  delete from public.provider_specializations where provider_id = p_user_id;
  delete from public.provider_car_details where provider_id = p_user_id;
  delete from public.providers where id = p_user_id;
  delete from public.vehicles where user_id = p_user_id;
  delete from public.profiles where id = p_user_id;
end;
$function$;

-- 4d) delete_user_account
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.notifications where user_id = uid;
  delete from public.orders where car_owner_id = uid or provider_id = uid;
  delete from public.vehicles where user_id = uid;
  delete from public.provider_car_details where provider_id = uid;
  delete from public.provider_specializations where provider_id = uid;
  delete from public.providers where id = uid;
  delete from public.profiles where id = uid;

  perform auth.admin_delete_user(uid);
end;
$function$;

-- 4e) update_pending_order is unused by the client and would bypass the new
--     derived-snapshot model — drop it.
drop function if exists public.update_pending_order(
  uuid, text, text, text, integer, double precision, double precision,
  text, text, boolean, boolean
);

-- 4f) handle_new_user — owner branch now writes a catalog-backed vehicle.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to ''
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

    -- ========================================================================
    -- Car owner: create the first catalog-backed vehicle.
    -- The client sends the chosen trim, model year, color and optional plate;
    -- the vehicles trigger validates all of them against the catalog.
    -- ========================================================================
    if v_role = 'car_owner'::public.user_role then
        if NEW.raw_user_meta_data ->> 'vehicle_trim_id' is null
           or btrim(NEW.raw_user_meta_data ->> 'vehicle_trim_id') = '' then
            raise exception 'MISSING_VEHICLE: a vehicle is required for car_owner accounts';
        end if;

        if NEW.raw_user_meta_data ->> 'vehicle_model_year' is null
           or btrim(NEW.raw_user_meta_data ->> 'vehicle_model_year') = '' then
            raise exception 'MISSING_VEHICLE_YEAR: vehicle model year is required';
        end if;

        if NEW.raw_user_meta_data ->> 'vehicle_color_id' is null
           or btrim(NEW.raw_user_meta_data ->> 'vehicle_color_id') = '' then
            raise exception 'MISSING_VEHICLE_COLOR: vehicle color is required';
        end if;

        insert into public.vehicles (
            user_id, trim_id, model_year, color_id,
            plate_letters, plate_digits, is_default, created_at
        ) values (
            NEW.id,
            NEW.raw_user_meta_data ->> 'vehicle_trim_id',
            nullif(NEW.raw_user_meta_data ->> 'vehicle_model_year', '')::integer,
            NEW.raw_user_meta_data ->> 'vehicle_color_id',
            nullif(btrim(NEW.raw_user_meta_data ->> 'vehicle_plate_letters'), ''),
            nullif(btrim(NEW.raw_user_meta_data ->> 'vehicle_plate_digits'), ''),
            true,
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

-- ============================================================================
-- 5) Drop the legacy table
-- ============================================================================
drop table if exists public.car_details;

commit;
