-- =============================================================================
-- Egyptian national ID validation for service orders.
--
-- Requirement:
--   A car_owner must not be able to create a service order without a valid
--   national ID. Enforced in three layers, all sharing identical rules:
--     1) public.is_valid_egyptian_national_id(text)  -- pure predicate
--     2) CHECK constraint on public.profiles          -- at-rest integrity
--     3) BEFORE INSERT trigger on public.orders and an explicit check inside
--        update_pending_order()                       -- at order time
--
-- Rules (identical to the Dart validator NationalIdUtils):
--   * Fold Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits to Latin.
--   * Exactly 14 digits.
--   * First digit 2 (born 1900-1999) or 3 (born 2000-2099).
--   * Digits 2-7 are YYMMDD and must form a real calendar date.
--   * That birth date must not be in the future.
--   * Digits 8-9 are a governorate code in
--     {01-04, 11-19, 21-29, 31-35, 88}.
--   * No checksum is invented.
--
-- Deliberately NO blanket UPDATE trigger on orders: providers must still be
-- able to accept / progress / complete existing orders whose owner predates
-- this requirement. Only fresh inserts and owner edits of their own pending
-- order are gated.
--
-- Existing rows (audited before writing this migration): 2 car_owners with
-- NULL national_id and 2 providers with valid IDs — so the constraint
-- validates cleanly.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Pure predicate. STABLE (not IMMUTABLE) because "not in the future"
--    depends on today's date.
-- -----------------------------------------------------------------------------
create or replace function public.is_valid_egyptian_national_id(p_id text)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id      text;
  v_century integer;
  v_year    integer;
  v_month   integer;
  v_day     integer;
  v_gov     integer;
  v_date    date;
begin
  if p_id is null then
    return false;
  end if;

  -- Fold Arabic-Indic and Extended Arabic-Indic digits to Latin.
  v_id := translate(
    p_id,
    '٠١٢٣٤٥٦٧٨٩' || '۰۱۲۳۴۵۶۷۸۹',
    '0123456789' || '0123456789'
  );

  -- Exactly 14 Latin digits.
  if v_id !~ '^[0-9]{14}$' then
    return false;
  end if;

  -- Century digit: 2 -> 1900-1999, 3 -> 2000-2099.
  if left(v_id, 1) not in ('2', '3') then
    return false;
  end if;

  v_century := case when left(v_id, 1) = '2' then 1900 else 2000 end;
  v_year    := v_century + substring(v_id from 2 for 2)::integer;
  v_month   := substring(v_id from 4 for 2)::integer;
  v_day     := substring(v_id from 6 for 2)::integer;

  -- Real calendar date (rejects month 00/13, day 32, Feb 31, ...).
  begin
    v_date := make_date(v_year, v_month, v_day);
  exception when others then
    return false;
  end;

  -- Not in the future.
  if v_date > current_date then
    return false;
  end if;

  -- Governorate code.
  v_gov := substring(v_id from 8 for 2)::integer;
  if v_gov not in (1, 2, 3, 4,
                   11, 12, 13, 14, 15, 16, 17, 18, 19,
                   21, 22, 23, 24, 25, 26, 27, 28, 29,
                   31, 32, 33, 34, 35, 88) then
    return false;
  end if;

  return true;
end;
$$;

comment on function public.is_valid_egyptian_national_id(text) is
  'Validates an Egyptian national ID: 14 digits, century 2/3, real non-future birth date, known governorate code. Folds Arabic-Indic digits first.';

-- -----------------------------------------------------------------------------
-- 2) CHECK constraint on profiles.
--    Allowed values: NULL, empty/whitespace, or a valid national ID. Existing
--    rows are validated by the final VALIDATE (audited to pass).
-- -----------------------------------------------------------------------------
alter table public.profiles
  drop constraint if exists profiles_national_id_format;

alter table public.profiles
  add constraint profiles_national_id_format
  check (
    national_id is null
    or btrim(national_id) = ''
    or public.is_valid_egyptian_national_id(national_id)
  )
  not valid;

alter table public.profiles
  validate constraint profiles_national_id_format;

-- -----------------------------------------------------------------------------
-- 3) Shared assertion: raise a distinct code when an owner lacks a valid ID.
--    SECURITY DEFINER + search_path = public so it can read profiles.national_id
--    regardless of RLS (called from triggers / definer RPCs).
-- -----------------------------------------------------------------------------
create or replace function public.assert_owner_national_id(p_owner uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_national_id text;
begin
  select p.national_id
    into v_national_id
    from public.profiles p
   where p.id = p_owner;

  if v_national_id is null or btrim(v_national_id) = '' then
    raise exception 'OWNER_NATIONAL_ID_MISSING';
  end if;

  if not public.is_valid_egyptian_national_id(v_national_id) then
    raise exception 'OWNER_NATIONAL_ID_INVALID';
  end if;
end;
$$;

revoke execute on function public.assert_owner_national_id(uuid) from public, anon;
grant execute on function public.assert_owner_national_id(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) BEFORE INSERT trigger on orders (insert only — never on update).
-- -----------------------------------------------------------------------------
create or replace function public.enforce_owner_national_id_on_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_owner_national_id(new.car_owner_id);
  return new;
end;
$$;

drop trigger if exists trg_orders_require_owner_national_id on public.orders;

create trigger trg_orders_require_owner_national_id
before insert on public.orders
for each row
execute function public.enforce_owner_national_id_on_order();

-- -----------------------------------------------------------------------------
-- 5) Owner editing their own pending order (update-in-place path) must also
--    carry a valid ID. Recreate update_pending_order with the check added;
--    every other line is unchanged from the LIVE definition (last touched by
--    20260919120000_respond_deadline_at_assignment.sql — i.e. editing does NOT
--    touch respond_deadline).
-- -----------------------------------------------------------------------------
create or replace function public.update_pending_order(
  p_order_id        uuid,
  p_service_type_id text,
  p_car_make        text,
  p_car_model       text,
  p_car_year        integer,
  p_latitude        double precision,
  p_longitude       double precision,
  p_notes           text,
  p_owner_phone     text,
  p_auto_cancel     boolean,
  p_share_phone     boolean
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.orders;
begin
  -- Owner must hold a valid national ID to (re)submit a pending order.
  perform public.assert_owner_national_id(auth.uid());

  update public.orders
     set service_type_id  = p_service_type_id,
         car_make         = p_car_make,
         car_model        = p_car_model,
         car_year         = p_car_year,
         latitude         = p_latitude,
         longitude        = p_longitude,
         notes            = p_notes,
         owner_phone      = p_owner_phone,
         auto_cancel      = p_auto_cancel,
         share_phone      = p_share_phone,
         updated_at       = now()
   where id = p_order_id
     and car_owner_id = auth.uid()
     and status = 'pending'
   returning * into v_row;

  if v_row.id is null then
    raise exception 'ORDER_NOT_FOUND_OR_NOT_PENDING';
  end if;

  return v_row;
end;
$$;

grant execute on function public.update_pending_order(uuid, text, text, text, integer, double precision, double precision, text, text, boolean, boolean) to authenticated;

revoke execute on function public.update_pending_order(uuid, text, text, text, integer, double precision, double precision, text, text, boolean, boolean) from public, anon;
