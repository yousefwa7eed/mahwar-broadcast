-- اللوحات المصرية ليست دائمًا 3 حروف + 3/4 أرقام: هناك لوحات شاذة
-- (حرفان، 5 حروف، حرف مكرر مثل «ددك»، أرقام أقل أو أكثر). القاعدة القديمة
-- كانت تحبس العميل على 17 حرفًا بالضبط و3 حروف و3-4 أرقام، فأي لوحة
-- غير تقليدية كانت تُرفض من السيرفر رغم صحتها على الأرض.
--
-- Egyptian plates are not always 3 letters + 3/4 digits. Some are irregular:
-- two letters, five letters, a repeated letter (e.g. «ددك»), fewer/more digits.
-- The client allowed only what the trigger allowed, so valid plates were rejected.
-- New rule: 1..5 Arabic letters (any of them, repeats allowed) and 1..7 digits.
-- Arabic-Indic digits are still stored as Western digits by the client, so the
-- column stays comparable and searchable.

create or replace function public.vehicles_before_write()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_year_from int;
  v_year_to   int;
  v_has_default boolean;
begin
  select g.year_from, g.year_to
    into v_year_from, v_year_to
  from public.vehicle_trims t
  join public.vehicle_generations g on g.id = t.generation_id
  where t.id = new.trim_id;

  if not found then
    raise exception 'VEHICLE_TRIM_NOT_FOUND';
  end if;

  if new.model_year < v_year_from
     or (v_year_to is not null and new.model_year > v_year_to) then
    raise exception 'INVALID_MODEL_YEAR';
  end if;

  if new.color_id is not null
     and not exists (select 1 from public.vehicle_colors c where c.id = new.color_id) then
    raise exception 'VEHICLE_COLOR_NOT_FOUND';
  end if;

  if new.plate_letters is not null or new.plate_digits is not null then
    new.plate_letters := btrim(new.plate_letters);
    new.plate_digits  := btrim(new.plate_digits);
    if new.plate_letters is null or new.plate_letters = ''
       or new.plate_digits is null or new.plate_digits = '' then
      raise exception 'INVALID_PLATE';
    end if;
    -- U+0621..U+064A: الحروف العربية فقط بلا تشكيل ولا أرقام. التكرار مسموح.
    -- Repeats are allowed and the count is not fixed (irregular plates exist).
    if new.plate_letters !~ '^[ء-ي]{1,5}$'
       or new.plate_digits !~ '^[0-9]{1,7}$' then
      raise exception 'INVALID_PLATE';
    end if;
  end if;

  if tg_op = 'INSERT' then
    if new.is_default then
      update public.vehicles
         set is_default = false
       where user_id = new.user_id and is_default;
    else
      select exists (
        select 1 from public.vehicles
        where user_id = new.user_id and is_default
      ) into v_has_default;
      if not v_has_default then
        new.is_default := true;
      end if;
    end if;
  elsif new.is_default and not old.is_default then
    update public.vehicles
       set is_default = false
     where user_id = new.user_id and id <> new.id and is_default;
  end if;

  new.updated_at := now();
  return new;
end;
$function$;
