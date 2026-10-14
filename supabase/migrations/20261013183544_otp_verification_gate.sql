-- =============================================================================
-- OTP verification gate — SERVER enforcement (was client-only / absent).
--
-- Problem: the phone-OTP step after signup was purely a client navigation
-- concern. Nothing on the server stopped an unverified account from acting:
--   * an unverified car_owner could create real orders
--     (create_order_for_provider only checked auth.uid()),
--   * a fresh provider is inserted by handle_new_user WITHOUT is_online, and
--     providers.is_online DEFAULTS TO TRUE — so a brand-new, unverified
--     provider was immediately "online" and visible in get_nearest_providers
--     (which is exactly the "unverified provider appears online" symptom),
--   * the legacy "Car owners create orders" INSERT policy never looked at
--     verification either.
--
-- Fix (defence in depth, all server-side):
--   1) is_phone_verified(uuid)      — parameterised, internal-only helper.
--   2) create_order_for_provider     — reject when the caller's phone is
--                                      unverified (PHONE_NOT_VERIFIED).
--   3) trg_providers_online_requires_verified — an unverified provider can
--      never be is_online = true. A client attempt raises PHONE_NOT_VERIFIED;
--      internal paths (signup default true, cron boundary flips) are silently
--      forced back to false instead of aborting the whole statement.
--   4) "Car owners create orders"    — WITH CHECK now also requires a verified
--                                      phone (direct-insert defence; the RPC is
--                                      SECURITY DEFINER and already gated).
--
-- get_my_phone_verified() (20260921000000) is re-used unchanged for the
-- caller-scoped checks. Verification truth is auth.users.phone_confirmed_at.
-- =============================================================================

-- 1) Parameterised verification helper for a *given* user id (the trigger needs
--    the row owner's status, not the caller's). Internal only: reading whether
--    an arbitrary uuid's phone is verified must not be client-exposed.
create or replace function public.is_phone_verified(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select u.phone_confirmed_at is not null
      from auth.users u
     where u.id = p_user_id
  ), false);
$$;

revoke all on function public.is_phone_verified(uuid) from public, anon, authenticated;

-- 2) create_order_for_provider — byte-for-byte the live body (verified against
--    pg_get_functiondef immediately before this migration) plus a single
--    PHONE_NOT_VERIFIED guard right after the authentication gate.
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

  -- Phone-verification gate: an account that has not completed SMS OTP may not
  -- create orders. Mirrors the app-side bootstrap gate (get_my_phone_verified).
  if not public.get_my_phone_verified() then
    raise exception 'PHONE_NOT_VERIFIED';
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

-- 3) An unverified provider must never be is_online = true.
--
--    * Client UPDATE (auth.uid() = the row owner) trying to go online while
--      unverified -> PHONE_NOT_VERIFIED (clear, translatable message).
--    * Any internal path (handle_new_user INSERT with is_online defaulting to
--      true, or the availability cron flipping a boundary) -> silently force
--      offline, so one unverified row can never abort a whole cron statement.
create or replace function public.enforce_provider_online_requires_verified_phone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_online is true and not public.is_phone_verified(new.id) then
    if auth.uid() = new.id then
      raise exception 'PHONE_NOT_VERIFIED';
    end if;
    new.is_online := false;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_providers_online_requires_verified on public.providers;
create trigger trg_providers_online_requires_verified
  before insert or update of is_online on public.providers
  for each row
  execute function public.enforce_provider_online_requires_verified_phone();

-- 4) Direct-insert defence: the legacy "Car owners create orders" policy never
--    looked at verification. The app creates orders through the SECURITY
--    DEFINER RPC (which bypasses RLS), so this only closes the direct path.
drop policy if exists "Car owners create orders" on public.orders;
create policy "Car owners create orders"
on public.orders
for insert
to authenticated
with check (
  auth.uid() = car_owner_id
  and public.get_my_phone_verified()
  and status = 'pending'::order_status
  and provider_id is null
  and offered_price is null
  and provider_notes is null
  and eta_minutes is null
  and provider_attachments is null
);
