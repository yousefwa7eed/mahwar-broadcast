-- =============================================================================
-- admin_analytics — تفاصيل أعمق للهوم: مخطط زمني + قمع تجربة المستخدم.
--
-- admin_dashboard_analytics():
--   series (آخر 14 يوم): INSTANT كل يوم CONTINUITY:
--     - users_created      (profiles الجدد في اليوم)
--     - orders_created     (طلبات جديدة)
--     - orders_completed   (طلبات اكتملت updated في اليوم)
--     - notifications_sent ( notifications/broadcast + الأحداث)
--
--   funnel  (تجربة المستخدم من التسجيل حتى إتمام طلب):
--     - registered        كل الحسابات
--     - phone_verified    لديها phone_verified_at
--     - active_last7d     دخلوا في آخر 7 أيام (last_sign_in)
--     - made_order        صاحبوا استخدم الطلب
--     - completed_order   طلبه اكتمل
--     - rated             قيموا منصة تقييم
--
--   retention  (نشط حسب آخر دخول): يوم / 7 / 30 يوم
--     + إجمالي مستخدمين حاشد بعملياتهم دائمة.
-- =============================================================================

create or replace function public.admin_dashboard_analytics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.assert_admin();

  return jsonb_build_object(
    'series', (
      select coalesce(jsonb_agg(x order by x.day), '[]'::jsonb)
      from (
        with days as (
          select generate_series(
            (current_date - interval '13 days')::date,
            current_date::date,
            interval '1 day'
          )::date as day
        )
        select
          d.day::text as day,
          (select count(*) from public.profiles p
             where p.created_at::date = d.day)                        as users_created,
          (select count(*) from public.orders o
             where o.created_at::date = d.day)                        as orders_created,
          (select count(*) from public.orders o
             where o.status = 'completed'
               and o.updated_at::date = d.day)                        as orders_completed,
          (select count(*) from public.notifications n
             where n.created_at::date = d.day)                        as notifications_sent
        from days d
      ) x
    ),
    'funnel', jsonb_build_object(
      'registered',    (select count(*) from public.profiles),
      'phone_verified',(select count(*) from public.profiles
                          where phone_verified_at is not null),
      'active_last7d', (select count(*) from public.profiles p
                          join auth.users au on au.id = p.id
                          where au.last_sign_in_at > now() - interval '7 days'),
      'made_order',    (select count(distinct o.car_owner_id)
                          from public.orders o)
      ,
      'completed_order', (select count(distinct o.car_owner_id)
                            from public.orders o
                            where o.status = 'completed'),
      'rated',         (select count(distinct r.user_id)
                          from public.ratings r)
    ),
    'retention', jsonb_build_object(
      'last_1d',  (select count(*) from public.profiles p
                     join auth.users au on au.id = p.id
                     where au.last_sign_in_at > now() - interval '1 day'),
      'last_7d',  (select count(*) from public.profiles p
                     join auth.users au on au.id = p.id
                     where au.last_sign_in_at > now() - interval '7 days'),
      'last_30d', (select count(*) from public.profiles p
                     join auth.users au on au.id = p.id
                     where au.last_sign_in_at > now() - interval '30 days'),
      'banned',   (select count(*) from auth.users u
                     where u.banned_until is not null
                       and u.banned_until > now()),
      'online_providers', (select count(*) from public.providers
                             where is_online = true)
    )
  );
end;
$$;

revoke all on function public.admin_dashboard_analytics() from public;
revoke all on function public.admin_dashboard_analytics() from anon;
grant execute on function public.admin_dashboard_analytics() to authenticated, service_role;
