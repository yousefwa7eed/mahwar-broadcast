-- =============================================================================
-- ITEM 1: an order exists only once a provider has been chosen and requested.
--
-- Before: service_request_screen inserted a real `orders` row (status
--   'pending', provider_id NULL) the moment the customer tapped "send", i.e.
--   before any provider was picked. Abandoning the provider list left an
--   orphaned row that expire_overdue_orders later flipped to 'cancelled'
--   ("response timeout").
--
-- After: the row is created by one atomic SECURITY DEFINER RPC at the exact
--   moment the customer confirms a provider. Nothing is written to the DB
--   before that; if the app dies mid-flow, no row exists.
--
-- The RPC mirrors the previous direct INSERT column set, plus:
--   * provider validation (exists + the SAME eligibility predicate
--     get_nearest_providers applies: is_online + service + distance),
--   * the respond_deadline stamping rule of assign_order_to_provider
--     (the BEFORE INSERT trigger trg_orders_apply_cancel_prefs forces
--      respond_deadline := NULL, so the deadline is stamped by a follow-up
--      UPDATE, exactly like assign_order_to_provider),
--   * attachment validation identical to set_order_attachments (cap 10),
--   * the 'new_order' notification for the provider.
--
-- Deliberately kept as-is in this step (do NOT touch): the "Car owners create
-- orders" INSERT policy, update_pending_order, assign_order_to_provider and the
-- expire_overdue_orders fallback.
-- =============================================================================

-- 1) Provider eligibility — the exact predicate get_nearest_providers filters on.
create or replace function public.is_provider_eligible_for_order(
  p_provider_id         uuid,
  p_service_type_id     text,
  p_owner_lat           double precision,
  p_owner_lng           double precision,
  p_max_distance_meters double precision default 50000
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.public_provider_profiles v
    where v.provider_id = p_provider_id
      and v.is_online = true
      and (p_service_type_id is null or v.services @> array[p_service_type_id])
      and public.earth_distance(
            public.ll_to_earth(p_owner_lat, p_owner_lng),
            public.ll_to_earth(v.latitude, v.longitude)
          ) <= p_max_distance_meters
  );
$$;

revoke execute on function public.is_provider_eligible_for_order(
  uuid, text, double precision, double precision, double precision
) from public;
revoke execute on function public.is_provider_eligible_for_order(
  uuid, text, double precision, double precision, double precision
) from anon;
grant execute on function public.is_provider_eligible_for_order(
  uuid, text, double precision, double precision, double precision
) to authenticated;

-- 2) Make get_nearest_providers reuse the shared predicate.
--    Signature, returns table (exact column names/types/order) and ORDER BY are
--    reproduced verbatim from 20260916143000 so `create or replace` is legal and
--    the client contract is untouched. Only the WHERE predicate is swapped for
--    the helper, so behaviour (is_online + service + distance) is identical.
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
  where public.is_provider_eligible_for_order(
          p.provider_id, service_filter, user_lat, user_lng, max_distance_meters
        )
  order by distance_meters asc;
end;
$$;

revoke execute on function public.get_nearest_providers(
  double precision, double precision, text, double precision
) from public;
revoke execute on function public.get_nearest_providers(
  double precision, double precision, text, double precision
) from anon;
grant execute on function public.get_nearest_providers(
  double precision, double precision, text, double precision
) to authenticated;

-- 3) Atomic order creation at provider confirmation.
create or replace function public.create_order_for_provider(
  p_provider_id     uuid,
  p_service_type_id text,
  p_car_make        text,
  p_car_model       text,
  p_car_year        integer,
  p_latitude        double precision,
  p_longitude       double precision,
  p_notes           text,
  p_owner_phone     text,
  p_auto_cancel     boolean,
  p_share_phone     boolean,
  p_address_text    text    default null,
  p_currency        text    default 'EGP',
  p_attachments     text[]  default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_id    uuid;
  v_url   text;
begin
  if v_owner is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if p_provider_id is null or p_provider_id = v_owner then
    raise exception 'PROVIDER_UNAVAILABLE';
  end if;

  if not exists (select 1 from public.providers pr where pr.id = p_provider_id) then
    raise exception 'PROVIDER_UNAVAILABLE';
  end if;

  if not public.is_provider_eligible_for_order(
           p_provider_id, p_service_type_id, p_latitude, p_longitude
         ) then
    raise exception 'PROVIDER_UNAVAILABLE';
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

  -- National-ID gate (trg_orders_require_owner_national_id) and the
  -- NULL-deadline forcing (trg_orders_apply_cancel_prefs) run here.
  insert into public.orders (
    car_owner_id, provider_id, service_type_id, status,
    car_make, car_model, car_year,
    latitude, longitude, address_text, notes,
    owner_phone, currency, auto_cancel, share_phone, attachments
  ) values (
    v_owner, p_provider_id, p_service_type_id, 'pending',
    p_car_make, p_car_model, p_car_year,
    p_latitude, p_longitude, p_address_text, p_notes,
    p_owner_phone, coalesce(p_currency, 'EGP'), p_auto_cancel, p_share_phone, p_attachments
  )
  returning id into v_id;

  -- The insert trigger forced respond_deadline := NULL; stamp the countdown
  -- now, exactly like assign_order_to_provider (5 minutes when auto_cancel).
  if p_auto_cancel then
    update public.orders
       set respond_deadline = now() + interval '5 minutes'
     where id = v_id;
  end if;

  insert into public.notifications (user_id, order_id, type, metadata)
  values (
    p_provider_id,
    v_id,
    'new_order',
    jsonb_build_object(
      'service_type_id', p_service_type_id,
      'service_name',
      (select st.name_ar from public.service_types st where st.id = p_service_type_id)
    )
  );

  return v_id;
end;
$$;

revoke all on function public.create_order_for_provider(
  uuid, text, text, text, integer, double precision, double precision,
  text, text, boolean, boolean, text, text, text[]
) from public;
revoke all on function public.create_order_for_provider(
  uuid, text, text, text, integer, double precision, double precision,
  text, text, boolean, boolean, text, text, text[]
) from anon;
grant execute on function public.create_order_for_provider(
  uuid, text, text, text, integer, double precision, double precision,
  text, text, boolean, boolean, text, text, text[]
) to authenticated;
