-- Migration: Rewrite ownership guards against the anon NULL-bypass.
-- Date: 2026-09-18
--
-- H1 sub-fix 2. The anon JWT has no `sub`, so auth.uid() is NULL for anonymous
-- calls, and `IF <id> <> auth.uid() THEN RAISE` never fires (NULL comparison).
-- Rewrite each guard as:
--     IF auth.uid() IS NULL OR <id> IS DISTINCT FROM auth.uid() THEN RAISE
-- which rejects NULL auth.uid() up front AND uses IS DISTINCT FROM so a NULL
-- comparison can never be silently treated as TRUE.
--
-- Functions rewritten here: owner_cancel_order, owner_confirm_price,
-- rate_provider, assign_order_to_provider, provider_reject_order,
-- provider_set_price (5-arg). The legacy 2-arg provider_set_price is dropped
-- later (H1 sub-fix 4); the hardened bodies from the never-applied
-- 20260902120000 migration are re-applied with these same guards in H1
-- sub-fix 3.

-- owner_cancel_order
CREATE OR REPLACE FUNCTION public.owner_cancel_order(p_order_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_owner    uuid;
  v_provider uuid;
  v_service  text;
  v_affected int;
begin
  select car_owner_id, provider_id, service_type_id
    into v_owner, v_provider, v_service
  from public.orders where id = p_order_id;

  if v_owner is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  if auth.uid() is null or v_owner is distinct from auth.uid() then
    raise exception 'NOT_OWNER';
  end if;

  update public.orders
  set status = 'cancelled',
      respond_deadline = null,
      updated_at = now()
  where id = p_order_id
    and status = 'pending';

  get diagnostics v_affected = row_count;
  if v_affected = 0 then
    raise exception 'ORDER_NOT_PENDING';
  end if;

  if v_provider is not null then
    insert into public.notifications (user_id, order_id, type, metadata)
    values (
      v_provider,
      p_order_id,
      'order_cancelled',
      jsonb_build_object(
        'service_type_id', v_service,
        'service_name', (select name_ar from public.service_types st where st.id = v_service),
        'by', 'owner'
      )
    );
  end if;
end;
$function$;
GRANT EXECUTE ON FUNCTION public.owner_cancel_order(uuid) TO authenticated;

-- owner_confirm_price
CREATE OR REPLACE FUNCTION public.owner_confirm_price(p_order_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF auth.uid() IS NULL OR v_order.car_owner_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized action';
  END IF;

  IF v_order.status != 'priced' THEN
    RAISE EXCEPTION 'Order status is not priced';
  END IF;

  UPDATE public.orders
  SET status = 'confirmed'
  WHERE id = p_order_id;

  INSERT INTO public.notifications (user_id, order_id, type, metadata)
  VALUES (v_order.provider_id, p_order_id, 'order_confirmed', jsonb_build_object('order_id', p_order_id));
END;
$function$;
GRANT EXECUTE ON FUNCTION public.owner_confirm_price(uuid) TO authenticated;

-- rate_provider
CREATE OR REPLACE FUNCTION public.rate_provider(p_order_id uuid, p_rating integer, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if auth.uid() is null or v_car_owner is distinct from auth.uid() then
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
$function$;
GRANT EXECUTE ON FUNCTION public.rate_provider(uuid, integer, text) TO authenticated;

-- assign_order_to_provider
CREATE OR REPLACE FUNCTION public.assign_order_to_provider(p_order_id uuid, p_provider_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_owner    uuid;
  v_service  text;
  v_provider uuid;
  v_affected int;
begin
  select car_owner_id, service_type_id, provider_id
    into v_owner, v_service, v_provider
  from public.orders where id = p_order_id;

  if v_owner is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  if auth.uid() is null or v_owner is distinct from auth.uid() then
    raise exception 'NOT_OWNER';
  end if;

  update public.orders
  set provider_id = p_provider_id,
      updated_at = now()
  where id = p_order_id
    and status = 'pending'
    and provider_id is null;

  get diagnostics v_affected = row_count;
  if v_affected = 0 then
    raise exception 'ORDER_NOT_PENDING';
  end if;

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
$function$;
GRANT EXECUTE ON FUNCTION public.assign_order_to_provider(uuid, uuid) TO authenticated;

-- provider_reject_order (status precondition is re-applied in H1 sub-fix 3)
CREATE OR REPLACE FUNCTION public.provider_reject_order(p_order_id uuid)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if auth.uid() is null or v_provider is distinct from auth.uid() then
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
$function$;
GRANT EXECUTE ON FUNCTION public.provider_reject_order(uuid) TO authenticated;

-- provider_set_price 5-arg (status precondition is re-applied in H1 sub-fix 3)
CREATE OR REPLACE FUNCTION public.provider_set_price(p_order_id uuid, p_price numeric, p_notes text DEFAULT NULL::text, p_eta_minutes integer DEFAULT NULL::integer, p_attachments text[] DEFAULT NULL::text[])
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if auth.uid() is null or v_provider is distinct from auth.uid() then
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
      provider_attachments = p_attachments,
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
      'eta_minutes', p_eta_minutes,
      'attachments', coalesce(p_attachments, '{}')
    )
  );

  return v_row;
end;
$function$;
GRANT EXECUTE ON FUNCTION public.provider_set_price(uuid, numeric, text, integer, text[]) TO authenticated;