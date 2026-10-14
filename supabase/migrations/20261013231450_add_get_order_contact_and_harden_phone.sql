-- 20261013231450_add_get_order_contact_and_harden_phone.sql

-- 1) get_order_contact: returns phone from profiles only if caller is assigned provider and order status='confirmed'
CREATE OR REPLACE FUNCTION public.get_order_contact(p_order_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS \\$
DECLARE
  v_provider_id uuid;
  v_owner_id    uuid;
  v_status      text;
  v_phone       text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT o.provider_id, o.car_owner_id, o.status
    INTO v_provider_id, v_owner_id, v_status
  FROM public.orders o
  WHERE o.id = p_order_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  IF v_status <> 'confirmed' THEN
    RETURN NULL;
  END IF;
  IF v_provider_id IS NULL OR v_provider_id <> auth.uid() THEN
    RETURN NULL;
  END IF;
  SELECT p.phone_number
    INTO v_phone
  FROM public.profiles p
  WHERE p.id = v_owner_id;
  RETURN v_phone;
END;
\\$;

REVOKE EXECUTE ON FUNCTION public.get_order_contact(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_order_contact(uuid) TO authenticated;

-- 2) Harden phone column before update
ALTER TABLE public.orders ALTER COLUMN owner_phone DROP NOT NULL;

-- 3) Update existing orders: null phone/share (defense + hygiene)
UPDATE public.orders
   SET owner_phone = NULL,
       share_phone = false
 WHERE (owner_phone IS NOT NULL) OR (share_phone IS true);

-- 4) Force-null trigger (BEFORE INSERT OR UPDATE)
CREATE OR REPLACE FUNCTION public.trg_orders_force_null_phone_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS \\$
BEGIN
  NEW.owner_phone := NULL;
  NEW.share_phone := false;
  RETURN NEW;
END;
\\$;

REVOKE EXECUTE ON FUNCTION public.trg_orders_force_null_phone_fn() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_orders_force_null_phone
BEFORE INSERT OR UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trg_orders_force_null_phone_fn();

-- 5) create_order_for_provider: keep signature identical, ignore params for phone/share, write NULL/false
CREATE OR REPLACE FUNCTION public.create_order_for_provider(p_provider_id uuid, p_service_type_id text, p_car_make text, p_car_model text, p_car_year integer, p_latitude double precision, p_longitude double precision, p_notes text, p_owner_phone text, p_auto_cancel boolean, p_share_phone boolean, p_address_text text DEFAULT NULL::text, p_currency text DEFAULT 'EGP'::text, p_attachments text[] DEFAULT NULL::text[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS \\$
declare
  v_owner uuid := auth.uid();
  v_id    uuid;
  v_url   text;
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
  if coalesce(array_length(p_attachments,1),0) > 10 then
    raise exception 'TOO_MANY_ATTACHMENTS';
  end if;
  if p_attachments is not null then
    foreach v_url in array p_attachments loop
      if not public.is_valid_order_attachment(v_url, v_owner) then
        raise exception 'INVALID_ATTACHMENT_URL';
      end if;
    end loop;
  end if;
  insert into public.orders (car_owner_id, provider_id, service_type_id, status, car_make, car_model, car_year, latitude, longitude, address_text, notes, owner_phone, currency, auto_cancel, share_phone, attachments)
  values (v_owner, p_provider_id, p_service_type_id, 'pending', p_car_make, p_car_model, p_car_year, p_latitude, p_longitude, p_address_text, p_notes, NULL, coalesce(p_currency,'EGP'), p_auto_cancel, false, p_attachments)
  returning id into v_id;
  if p_auto_cancel then
    update public.orders set respond_deadline = now()+interval '5 minutes' where id=v_id;
  end if;
  insert into public.notifications (user_id, order_id, type, metadata)
  values (p_provider_id, v_id, 'new_order', jsonb_build_object('service_type_id',p_service_type_id,'service_name',(select st.name_ar from public.service_types st where st.id=p_service_type_id)));
  return v_id;
end;
\\$;

-- 6) update_pending_order: keep signature identical, ignore params for phone/share, write NULL/false
CREATE OR REPLACE FUNCTION public.update_pending_order(p_order_id uuid, p_service_type_id text, p_car_make text, p_car_model text, p_car_year integer, p_latitude double precision, p_longitude double precision, p_notes text, p_owner_phone text, p_auto_cancel boolean, p_share_phone boolean)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS \\$
declare
  v_row public.orders;
begin
  perform public.assert_owner_national_id(auth.uid());
  update public.orders
     set service_type_id=p_service_type_id, car_make=p_car_make, car_model=p_car_model, car_year=p_car_year,
         latitude=p_latitude, longitude=p_longitude, notes=p_notes, owner_phone=NULL,
         auto_cancel=p_auto_cancel, share_phone=false, updated_at=now()
   where id=p_order_id and car_owner_id=auth.uid() and status='pending'
   returning * into v_row;
  if v_row.id is null then
    raise exception 'ORDER_NOT_FOUND_OR_NOT_PENDING';
  end if;
  return v_row;
end;
\\$;
