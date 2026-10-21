-- =============================================================================
-- Phase 5B: orders board for the dashboard.
--   * admin_list_orders(page, size, status, search)  -> paginated, filterable
--     rows with owner/provider names (email fallback like recent-activity).
--   * admin_export_orders(status, search)            -> up to 5000 rows, audited.
-- Same guard pattern as the other admin RPCs (assert_admin, security definer,
-- search_path='', revoked from public/anon).
-- =============================================================================

drop function if exists public.admin_list_orders(int, int, text, text);
drop function if exists public.admin_export_orders(text, text);

create or replace function public.admin_list_orders(
  p_page      int  default 1,
  p_page_size int  default 25,
  p_status    text default null,
  p_search    text default null
)
returns table (
  id             uuid,
  service        text,
  status         text,
  offered_price  numeric,
  currency       text,
  owner_name     text,
  provider_name  text,
  owner_phone    text,
  car_title      text,
  address_text   text,
  eta_minutes    int,
  notes          text,
  provider_notes text,
  attachments_count int,
  provider_attachments_count int,
  share_phone    boolean,
  created_at     timestamptz,
  updated_at     timestamptz,
  total_count    bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_page   int := greatest(coalesce(p_page, 1), 1);
  v_size   int := least(greatest(coalesce(p_page_size, 25), 1), 100);
  v_status public.order_status;
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
begin
  perform public.assert_admin();

  v_status := case
    when coalesce(p_status, '') in
      ('pending','priced','confirmed','rejected_by_provider','rejected_by_owner','cancelled','completed')
    then p_status::public.order_status
  end;

  return query
  with base as (
    select
      o.id,
      st.name_ar                              as service,
      o.status::text                          as status_text,
      o.offered_price,
      o.currency,
      coalesce(owner_p.full_name, owner_au.email)   as owner_name,
      coalesce(provider_p.full_name, provider_au.email) as provider_name,
      o.owner_phone,
      nullif(trim(concat(o.car_make, ' ', o.car_model, ' ', coalesce(o.car_year::text, ''))), '') as car_title,
      o.address_text,
      o.eta_minutes,
      o.notes,
      o.provider_notes,
      coalesce(array_length(o.attachments::text[], 1), 0)::int          as attachments_count,
      coalesce(array_length(o.provider_attachments::text[], 1), 0)::int as provider_attachments_count,
      o.share_phone,
      o.created_at,
      o.updated_at,
      count(*) over ()                        as total
    from (
      select o.*, row_number() over (order by o.created_at desc) as rn
      from public.orders o
    ) o
    left join public.service_types st      on st.id = o.service_type_id
    left join public.profiles owner_p      on owner_p.id = o.car_owner_id
    left join auth.users    owner_au       on owner_au.id = o.car_owner_id
    left join public.profiles provider_p  on provider_p.id = o.provider_id
    left join auth.users    provider_au    on provider_au.id = o.provider_id
    where (v_status is null or o.status = v_status)
      and (
        v_search is null
        or o.address_text ilike '%' || v_search || '%'
        or o.notes        ilike '%' || v_search || '%'
        or coalesce(owner_p.full_name, owner_au.email)  ilike '%' || v_search || '%'
        or coalesce(provider_p.full_name, provider_au.email) ilike '%' || v_search || '%'
        or st.name_ar ilike '%' || v_search || '%'
        or o.owner_phone ilike '%' || v_search || '%'
      )
  )
  select
    b.id, b.service, b.status_text, b.offered_price, b.currency,
    b.owner_name, b.provider_name, b.owner_phone, b.car_title,
    b.address_text, b.eta_minutes, b.notes, b.provider_notes,
    b.attachments_count, b.provider_attachments_count, b.share_phone,
    b.created_at, b.updated_at, b.total
  from base b
  order by b.created_at desc, b.id
  limit v_size
  offset (v_page - 1) * v_size;
end;
$$;

revoke all on function public.admin_list_orders(int, int, text, text) from public;
revoke all on function public.admin_list_orders(int, int, text, text) from anon;
grant execute on function public.admin_list_orders(int, int, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
create or replace function public.admin_export_orders(
  p_status text default null,
  p_search text default null
)
returns table (
  id             uuid,
  service        text,
  status         text,
  offered_price  numeric,
  currency       text,
  owner_name     text,
  provider_name  text,
  owner_phone    text,
  car_title      text,
  address_text   text,
  eta_minutes    int,
  notes          text,
  provider_notes text,
  attachments_count int,
  provider_attachments_count int,
  share_phone    boolean,
  created_at     timestamptz,
  updated_at     timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_status public.order_status;
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_marked bigint;
begin
  perform public.assert_admin();

  v_status := case
    when coalesce(p_status, '') in
      ('pending','priced','confirmed','rejected_by_provider','rejected_by_owner','cancelled','completed')
    then p_status::public.order_status
  end;

  with base as (
    select
      o.id,
      st.name_ar                              as service,
      o.status::text                          as status_text,
      o.offered_price,
      o.currency,
      coalesce(owner_p.full_name, owner_au.email)   as owner_name,
      coalesce(provider_p.full_name, provider_au.email) as provider_name,
      o.owner_phone,
      nullif(trim(concat(o.car_make, ' ', o.car_model, ' ', coalesce(o.car_year::text, ''))), '') as car_title,
      o.address_text,
      o.eta_minutes,
      o.notes,
      o.provider_notes,
      coalesce(array_length(o.attachments::text[], 1), 0)::int          as attachments_count,
      coalesce(array_length(o.provider_attachments::text[], 1), 0)::int as provider_attachments_count,
      o.share_phone,
      o.created_at,
      o.updated_at
    from (
      select o.*, row_number() over (order by o.created_at desc) as rn
      from public.orders o
    ) o
    left join public.service_types st      on st.id = o.service_type_id
    left join public.profiles owner_p      on owner_p.id = o.car_owner_id
    left join auth.users    owner_au       on owner_au.id = o.car_owner_id
    left join public.profiles provider_p  on provider_p.id = o.provider_id
    left join auth.users    provider_au    on provider_au.id = o.provider_id
    where (v_status is null or o.status = v_status)
      and (
        v_search is null
        or o.address_text ilike '%' || v_search || '%'
        or o.notes        ilike '%' || v_search || '%'
        or coalesce(owner_p.full_name, owner_au.email)  ilike '%' || v_search || '%'
        or coalesce(provider_p.full_name, provider_au.email) ilike '%' || v_search || '%'
        or st.name_ar ilike '%' || v_search || '%'
        or o.owner_phone ilike '%' || v_search || '%'
      )
      and o.rn <= 5000
  )
  select
    b.id, b.service, b.status_text, b.offered_price, b.currency,
    b.owner_name, b.provider_name, b.owner_phone, b.car_title,
    b.address_text, b.eta_minutes, b.notes, b.provider_notes,
    b.attachments_count, b.provider_attachments_count, b.share_phone,
    b.created_at, b.updated_at
  from base b
  order by b.created_at desc;

  get diagnostics v_marked = row_count;

  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (
    auth.uid(),
    'export_orders',
    null,
    jsonb_build_object(
      'rows_returned', v_marked,
      'status',        p_status,
      'search',        v_search
    )
  );
end;
$$;

revoke all on function public.admin_export_orders(text, text) from public;
revoke all on function public.admin_export_orders(text, text) from anon;
grant execute on function public.admin_export_orders(text, text) to authenticated, service_role;