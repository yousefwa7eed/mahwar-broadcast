-- =============================================================================
-- admin_paths — تتبع مسارات المستخدمين داخل التطبيق (أي شاشة/كم مدة/مَن بعدما).
--
-- جدول public.page_views
--   row واحد لكل «زيارة شاشة»: أي مستخدم، اسم الشاشة (مسار go_router)،
--   متى دخل (entered_at)، وقضى قد إيه (duration_sec).
--   RLS: المستخدم المصادَق يقدر يدرج صفوف لنفسه فقط (auth.uid() = user_id)
--   ولا يقرأ/يعدل أي شيء. القراءة للوحلة عبر admin_page_paths() فقط.
-- =============================================================================

create table if not exists public.page_views (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users on delete cascade,
  screen text not null,
  entered_at timestamptz not null default now(),
  duration_sec int not null default 0 check (duration_sec >= 0 and duration_sec <= 600),
  created_at timestamptz not null default now()
);

alter table public.page_views enable row level security;

create policy page_views_insert_own
  on public.page_views
  for insert
  to authenticated
  with check (auth.uid() = user_id);

revoke all on public.page_views from public, anon;
grant insert on public.page_views to authenticated;

-- =============================================================================
-- admin_page_paths() — تجميع مركز حسب الدور (car_owner / provider):
--   screens: [{screen, visits, avg_sec, total_sec}]
--   paths  : [{from, to, count, avg_sec}]  (الانتقال من شاشة → شاشة، بدون
--             مكرر نفسه ولا placeholder، على الأكثر 30 مسار شائع)
--   users / events لكل دور، ووقت توليد البيانات.
-- =============================================================================

create or replace function public.admin_page_paths()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  vl jsonb;
  vp jsonb;
  -- مهم: jsonb_set لا ينشئ الكائنات الوسيطة — يجب أن يكون 'roles' موجودًا مسبقًا
  v_out jsonb := '{"roles":{},"generated_at":null}'::jsonb;
  v_role text;
begin
  perform public.assert_admin();

  foreach v_role in array array['car_owner', 'provider'] loop
    select
      jsonb_build_object(
        'users',  (select coalesce(count(distinct user_id), 0) from public.page_views pv
                     join public.profiles p on p.id = pv.user_id
                     where p.role::text = v_role),
        'events', (select coalesce(count(*), 0) from public.page_views pv
                     join public.profiles p on p.id = pv.user_id
                     where p.role::text = v_role),
        'screens',(
          select coalesce(jsonb_agg(row_to_json(x) order by x.visits desc), '[]'::jsonb)
          from (
            select
              pv.screen                                as screen,
              count(*)::int                            as visits,
              round(avg(greatest(pv.duration_sec, 0)))::int as avg_sec,
              sum(pv.duration_sec)::int                as total_sec
            from public.page_views pv
            join public.profiles p on p.id = pv.user_id
            where p.role::text = v_role
            group by pv.screen
          ) as row_to_json
        ),
        'paths',  (
          select coalesce(jsonb_agg(y order by y.count desc), '[]'::jsonb)
          from (
            select
              vp2.prev                                      as from,
              vp2.screen                                    as to,
              count(*)::int                                 as count,
              round(avg(greatest(vp2.duration_sec, 0)))::int as avg_sec
            from (
              select
                pv.user_id,
                pv.screen,
                greatest(pv.duration_sec, 0)                       as duration_sec,
                lag(pv.screen) over (partition by pv.user_id
                                     order by pv.entered_at) as prev
              from public.page_views pv
              join public.profiles p on p.id = pv.user_id
              where p.role::text = v_role
            ) vp2
            where vp2.prev is not null
              and vp2.prev <> vp2.screen
            group by vp2.prev, vp2.screen
            order by count(*) desc
            limit 30
          ) as y
        )
      )
    into vl
    from (select 1) as z;
    v_out := jsonb_set(v_out, array['roles', v_role], vl);
  end loop;

  v_out := jsonb_set(v_out, '{generated_at}',
                     to_jsonb(to_char(now(), 'YYYY-MM-DD HH24:MI'))) ;
  return v_out;
end;
$$;

revoke all on function public.admin_page_paths() from public;
revoke all on function public.admin_page_paths() from anon;
grant execute on function public.admin_page_paths() to authenticated, service_role;
