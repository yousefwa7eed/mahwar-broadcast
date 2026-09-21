-- =============================================================================
-- Order full flow: nearest providers, provider details, assignment, pricing,
-- accept/reject, completion, ratings + realtime.
-- =============================================================================

-- 1) Ratings table (must exist before the view references it)
create table if not exists public.ratings (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references public.orders(id) on delete cascade,
  provider_id uuid not null references public.providers(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  rating      integer not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  unique (order_id)
);

alter table public.ratings enable row level security;

create policy if not exists "Owners rate orders" on public.ratings
  for insert with check (auth.uid() = user_id);

create policy if not exists "Users view ratings for them" on public.ratings
  for select using (auth.uid() = user_id or auth.uid() = provider_id);

-- 2) completed status for order_status enum
do $$
begin
  alter type public.order_status add value if not exists 'completed';
exception
  when duplicate_object then null;
end $$;

-- 3) Extra order columns
alter table public.orders add column if not exists provider_notes text;
alter table public.orders add column if not exists eta_minutes integer;

-- 4) View used by get_nearest_providers (was missing -> function errored 42P01)
create or replace view public.public_provider_profiles as
select
  pr.id as provider_id,
  pf.full_name,
  pf.phone_number,
  pr.workshop_name,
  pr.address,
  pr.latitude,
  pr.longitude,
  pr.support_scope,
  pr.has_vehicle,
  pr.vehicle_type,
  pr.vehicle_specs,
  pr.is_online,
  pr.created_at,
  coalesce(rt.avg_rating, 0)::double precision       as avg_rating,
  coalesce(rt.rating_count, 0)::bigint               as rating_count,
  coalesce(ar.services, '{}')                        as services
from public.providers pr
join public.profiles pf on pf.id = pr.id
left join (
  select provider_id, avg(rating)::double precision as avg_rating, count(*)::bigint as rating_count
  from public.ratings
  group by provider_id
) rt on rt.provider_id = pr.id
left join (
  select provider_id, array_agg(service_type_id order by service_type_id)::text[] as services
  from public.provider_specializations
  group by provider_id
) ar on ar.provider_id = pr.id;

-- 5) Rewrite get_nearest_providers -> returns phone + rating + services,
--    uses aggregation properly (no accidental duplicates), fixed search_path.
drop function if exists public.get_nearest_providers(double precision, double precision, text, double precision);
create or replace function public.get_nearest_providers(
  user_lat double precision,
  user_lng double precision,
  service_filter text default null,
  max_distance_meters double precision default 50000
)
returns table(
  provider_id uuid,
  full_name text,
  phone_number text,
  workshop_name text,
  address text,
  latitude double precision,
  longitude double precision,
  distance_meters double precision,
  support_scope public.support_scope,
  has_vehicle boolean,
  is_online boolean,
  avg_rating double precision,
  rating_count bigint,
  services text[]
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select
    p.provider_id,
    p.full_name,
    p.phone_number,
    p.workshop_name,
    p.address,
    p.latitude,
    p.longitude,
    public.earth_distance(
      public.ll_to_earth(user_lat, user_lng),
      public.ll_to_earth(p.latitude, p.longitude)
    ) as distance_meters,
    p.support_scope,
    p.has_vehicle,
    p.is_online,
    p.avg_rating,
    p.rating_count,
    p.services
  from public.public_provider_profiles p
  where p.is_online = true
    and (service_filter is null or p.services @> array[service_filter])
    and public.earth_distance(
      public.ll_to_earth(user_lat, user_lng),
      public.ll_to_earth(p.latitude, p.longitude)
    ) <= max_distance_meters
  order by distance_meters asc;
end;
$$;

-- =============================================================================
-- RPCs. Orders/notifications have no UPDATE/INSERT client policies, so every
-- state transition goes through a SECURITY DEFINER RPC that also writes the
-- corresponding notification atomically.
-- =============================================================================

-- Public profile lookup (profiles RLS only allows reading your own row)
drop function if exists public.get_public_profile(uuid);
create or replace function public.get_public_profile(p_user_id uuid)
returns table(full_name text, phone_number text, role public.user_role)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select pf.full_name, pf.phone_number, pf.role
  from public.profiles pf
  where pf.id = p_user_id;
end;
$$;

-- Provider public details (needed because owner RLS hides other profiles/specializations)
drop function if exists public.get_provider_details(uuid);
create or replace function public.get_provider_details(p_provider_id uuid)
returns table(
  provider_id uuid,
  full_name text,
  phone_number text,
  workshop_name text,
  address text,
  latitude double precision,
  longitude double precision,
  support_scope public.support_scope,
  has_vehicle boolean,
  vehicle_type text,
  vehicle_specs text,
  is_online boolean,
  avg_rating double precision,
  rating_count bigint,
  services text[]
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select
    p.provider_id, p.full_name, p.phone_number, p.workshop_name, p.address,
    p.latitude, p.longitude, p.support_scope, p.has_vehicle, p.vehicle_type,
    p.vehicle_specs, p.is_online, p.avg_rating, p.rating_count, p.services
  from public.public_provider_profiles p
  where p.provider_id = p_provider_id
  limit 1;
end;
$$;

-- Owner picks a provider; sends request to that provider (step: settle on provider)
drop function if exists public.assign_order_to_provider(uuid, uuid);
create or replace function public.assign_order_to_provider(p_order_id uuid, p_provider_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_service text;
  v_order_pending boolean;
begin
  select car_owner_id, service_type_id into v_owner, v_service
  from public.orders where id = p_order_id;

  if v_owner is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  select exists(
    select 1 from public.orders o
    where o.id = p_order_id and o.status = 'pending' and o.provider_id is null
  ) into v_order_pending;

  if v_order_pending is not true then
    raise exception 'ORDER_NOT_PENDING';
  end if;

  if v_owner <> auth.uid() then
    raise exception 'NOT_OWNER';
  end if;

  update public.orders
  set provider_id = p_provider_id, updated_at = now()
  where id = p_order_id;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    p_provider_id,
    p_order_id,
    'new_order',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service)
    )
  );
end;
$$;

-- Provider prices the order
drop function if exists public.provider_set_price(uuid, numeric, text, integer);
create or replace function public.provider_set_price(
  p_order_id uuid,
  p_price numeric,
  p_notes text default null,
  p_eta_minutes integer default null
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_owner uuid;
  v_service text;
  v_row public.orders;
begin
  select provider_id, car_owner_id, service_type_id into v_provider, v_owner, v_service
  from public.orders where id = p_order_id;

  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;
  if v_provider <> auth.uid() then
    raise exception 'NOT_PROVIDER';
  end if;
  if p_price is null or p_price <= 0 then
    raise exception 'INVALID_PRICE';
  end if;

  update public.orders
  set status = 'priced',
      offered_price = p_price,
      provider_notes = p_notes,
      eta_minutes = p_eta_minutes,
      updated_at = now()
  where id = p_order_id
  returning * into v_row;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_owner,
    p_order_id,
    'price_offer',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service),
      'price', p_price,
      'provider_notes', p_notes,
      'eta_minutes', p_eta_minutes
    )
  );

  return v_row;
end;
$$;

-- Provider rejects the order
drop function if exists public.provider_reject_order(uuid);
create or replace function public.provider_reject_order(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_owner uuid;
  v_service text;
  v_row public.orders;
begin
  select provider_id, car_owner_id, service_type_id into v_provider, v_owner, v_service
  from public.orders where id = p_order_id;

  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;
  if v_provider <> auth.uid() then
    raise exception 'NOT_PROVIDER';
  end if;

  update public.orders
  set status = 'rejected_by_provider', updated_at = now()
  where id = p_order_id
  returning * into v_row;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_owner,
    p_order_id,
    'order_rejected',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service),
      'by', 'provider'
    )
  );

  return v_row;
end;
$$;

-- Owner accepts the offered price
drop function if exists public.owner_accept_price(uuid);
create or replace function public.owner_accept_price(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_service text;
  v_row public.orders;
begin
  select provider_id, service_type_id into v_provider, v_service
  from public.orders where id = p_order_id;

  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;

  update public.orders
  set status = 'confirmed', updated_at = now()
  where id = p_order_id and status = 'priced' and car_owner_id = auth.uid()
  returning * into v_row;

  if not found then
    raise exception 'NOT_PRICED_OR_NOT_OWNER';
  end if;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_provider,
    p_order_id,
    'order_confirmed',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service)
    )
  );

  return v_row;
end;
$$;

-- Owner rejects the offered price
drop function if exists public.owner_reject_price(uuid);
create or replace function public.owner_reject_price(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_service text;
  v_row public.orders;
begin
  select provider_id, service_type_id into v_provider, v_service
  from public.orders where id = p_order_id;

  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;

  update public.orders
  set status = 'rejected_by_owner', updated_at = now()
  where id = p_order_id and status = 'priced' and car_owner_id = auth.uid()
  returning * into v_row;

  if not found then
    raise exception 'NOT_PRICED_OR_NOT_OWNER';
  end if;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_provider,
    p_order_id,
    'order_rejected',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service),
      'by', 'owner'
    )
  );

  return v_row;
end;
$$;

-- Provider marks the order as done
drop function if exists public.provider_complete_order(uuid);
create or replace function public.provider_complete_order(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_service text;
  v_row public.orders;
begin
  select car_owner_id, service_type_id into v_owner, v_service
  from public.orders where id = p_order_id;

  if not exists (
    select 1 from public.orders
    where id = p_order_id and provider_id = auth.uid() and status = 'confirmed'
  ) then
    raise exception 'NOT_CONFIRMED_OR_NOT_PROVIDER';
  end if;

  update public.orders
  set status = 'completed', updated_at = now()
  where id = p_order_id
  returning * into v_row;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_owner,
    p_order_id,
    'order_completed',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service)
    )
  );

  return v_row;
end;
$$;

-- Owner rates the provider after completion (max one per order)
drop function if exists public.rate_provider(uuid, integer, text);
create or replace function public.rate_provider(
  p_order_id uuid,
  p_rating integer,
  p_comment text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider uuid;
  v_service text;
  v_car_owner uuid;
  v_is_completed boolean;
  v_already_rated boolean;
begin
  select provider_id, service_type_id, car_owner_id into v_provider, v_service, v_car_owner
  from public.orders where id = p_order_id;

  if v_car_owner is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_car_owner <> auth.uid() then
    raise exception 'NOT_OWNER';
  end if;
  if v_provider is null then
    raise exception 'NOT_ASSIGNED';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'INVALID_RATING';
  end if;

  select status = 'completed' into v_is_completed from public.orders where id = p_order_id;
  if v_is_completed is not true then
    raise exception 'ORDER_NOT_COMPLETED';
  end if;

  select exists(select 1 from public.ratings where order_id = p_order_id) into v_already_rated;
  if v_already_rated then
    raise exception 'ALREADY_RATED';
  end if;

  insert into public.ratings (order_id, provider_id, user_id, rating, comment)
  values (p_order_id, v_provider, v_car_owner, p_rating, p_comment);

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    v_provider,
    p_order_id,
    'rating_received',
    jsonb_build_object(
      'service_type_id', v_service,
      'service_name', (select name_ar from public.service_types st where st.id = v_service),
      'rating', p_rating
    )
  );
end;
$$;

-- =============================================================================
-- Realtime: publish order/notification/rating changes.
-- =============================================================================
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.ratings;