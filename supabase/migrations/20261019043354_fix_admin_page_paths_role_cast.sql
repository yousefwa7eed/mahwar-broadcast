-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20261019043354 | name: fix_admin_page_paths_role_cast
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- SUPERSEDED BY: 20261019043909_fix_admin_page_paths_jsonb_root (jsonb root fix).
-- =============================================================================
drop function if exists public.admin_page_paths();

create or replace function public.admin_page_paths()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  vl jsonb;
  v_out jsonb := '{}'::jsonb;
  v_role text;
begin
  perform public.assert_admin();

  foreach v_role in array array['car_owner', 'provider'] loop
    select
      jsonb_build_object(
        'users',  (select coalesce(count(distinct pv.user_id), 0) from public.page_views pv
                     join public.profiles p on p.id = pv.user_id
                     where p.role::text = v_role),
        'events', (select coalesce(count(*), 0) from public.page_views pv
                     join public.profiles p on p.id = pv.user_id
                     where p.role::text = v_role),
        'screens',(
          select coalesce(jsonb_agg(r.order_rows order by (r.order_rows->>'visits')::int desc), '[]'::jsonb)
          from (
            select
              jsonb_build_object(
                'screen',    pv.screen,
                'visits',    count(*)::int,
                'avg_sec',   round(avg(greatest(pv.duration_sec, 0)))::int,
                'total_sec', sum(pv.duration_sec)::int
              ) as order_rows
            from public.page_views pv
            join public.profiles p on p.id = pv.user_id
            where p.role::text = v_role
            group by pv.screen
          ) r
        ),
        'paths',  (
          select coalesce(jsonb_agg(y.order_rows order by (y.order_rows->>'count')::int desc), '[]'::jsonb)
          from (
            select
              jsonb_build_object(
                'from',    vp2.prev,
                'to',      vp2.next_screen,
                'count',   count(*)::int,
                'avg_sec', round(avg(greatest(vp2.duration_sec, 0)))::int
              ) as order_rows
            from (
              select
                pv.user_id,
                pv.screen                                   as next_screen,
                greatest(pv.duration_sec, 0)                as duration_sec,
                p.role::text                                as role_key,
                lag(pv.screen) over (partition by pv.user_id order by pv.entered_at) as prev
              from public.page_views pv
              join public.profiles p on p.id = pv.user_id
            ) vp2
            where vp2.role_key = v_role
              and vp2.prev is not null
              and vp2.prev <> vp2.next_screen
            group by vp2.prev, vp2.next_screen
          ) y
        )
      )
    into vl
    from (select 1) as z;
    v_out := jsonb_set(v_out, array['roles', v_role], vl);
  end loop;

  v_out := jsonb_set(v_out, '{generated_at}', to_jsonb(to_char(now(), 'YYYY-MM-DD HH24:MI')));
  return v_out;
end;
$$;

revoke all on function public.admin_page_paths() from public;
revoke all on function public.admin_page_paths() from anon;
grant execute on function public.admin_page_paths() to authenticated, service_role;
