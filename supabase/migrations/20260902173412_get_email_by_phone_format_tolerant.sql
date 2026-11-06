-- =============================================================================
-- RESTORED 2026-11-06 from the live project (trgesfzojaoirutkkfcs).
-- applied as: 20260902173412 | name: get_email_by_phone_format_tolerant
-- source: supabase_migrations.schema_migrations.statements (array joined with ';')
-- No repo file existed for this version (drift repair). Already applied in production.
-- =============================================================================
create or replace function public.get_email_by_phone(p_phone text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_clean text;
begin
  -- Normalize the incoming phone the same way the client does, so login is
  -- tolerant of local (0xxx), international (+20/0020), and spaced formats.
  v_clean := translate(p_phone, ' ()-', '');
  if v_clean like '+20%' then
    v_clean := '0' || substring(v_clean from 4);
  elsif v_clean like '0020%' then
    v_clean := '0' || substring(v_clean from 5);
  end if;

  -- Match against the same normalized column. We compare both the raw value
  -- and its normalized form so legacy rows stored in any format still resolve.
  select email into v_email
  from public.profiles
  where phone_number = v_clean
     or translate(phone_number, ' ()-', '') = v_clean
  limit 1;

  return v_email;
end;
$$;

grant execute on function public.get_email_by_phone(text) to anon;
grant execute on function public.get_email_by_phone(text) to authenticated;
