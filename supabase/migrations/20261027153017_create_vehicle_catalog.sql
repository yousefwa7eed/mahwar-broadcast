-- مخطط كتالوج السيارات — مطبَّق على القاعدة الحيّة (applied as 20261027153017).
--
-- الهيكل: ماركة → موديل → جيل (نطاق سنوات) → فئة (trim).
-- المعرّفات نصية (slug) ثابتة، وهي نفسها المستخدمة في الكاش المحلي داخل التطبيق.

begin;

-- ============================================================================
-- Enums
-- ============================================================================
do $$ begin
  create type public.vehicle_body_type as enum
    ('sedan', 'hatchback', 'suv', 'crossover', 'pickup', 'van', 'mpv', 'coupe', 'wagon');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.vehicle_fuel as enum
    ('petrol', 'diesel', 'hybrid', 'electric', 'cng');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.vehicle_transmission as enum
    ('manual', 'automatic', 'cvt', 'dct');
exception when duplicate_object then null; end $$;

-- ============================================================================
-- Catalog tables
-- ============================================================================
create table if not exists public.vehicle_brands (
  id            text primary key,
  name_ar       text not null,
  name_en       text not null,
  country_code  text,
  logo_asset    text,
  brand_color   text,
  is_popular    boolean not null default false,
  sort_order    integer not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

create table if not exists public.vehicle_models (
  id          text primary key,
  brand_id    text not null references public.vehicle_brands(id) on delete cascade,
  name_ar     text not null,
  name_en     text not null,
  body_type   public.vehicle_body_type not null,
  sort_order  integer not null default 0,
  is_active   boolean not null default true
);
create index if not exists vehicle_models_brand_idx on public.vehicle_models(brand_id);

create table if not exists public.vehicle_generations (
  id          text primary key,
  model_id    text not null references public.vehicle_models(id) on delete cascade,
  year_from   integer not null check (year_from between 1950 and 2100),
  year_to     integer check (year_to is null or year_to between year_from and 2100),
  name_ar     text not null,
  name_en     text not null,
  sort_order  integer not null default 0,
  is_active   boolean not null default true
);
create index if not exists vehicle_generations_model_idx on public.vehicle_generations(model_id);

create table if not exists public.vehicle_trims (
  id            text primary key,
  generation_id text not null references public.vehicle_generations(id) on delete cascade,
  name_ar       text not null,
  name_en       text not null,
  engine_cc     integer check (engine_cc is null or engine_cc >= 0),
  fuel          public.vehicle_fuel,
  transmission  public.vehicle_transmission,
  horsepower    integer check (horsepower is null or horsepower > 0),
  seats         integer check (seats is null or seats between 2 and 9),
  sort_order    integer not null default 0,
  is_active     boolean not null default true
);
create index if not exists vehicle_trims_generation_idx on public.vehicle_trims(generation_id);

create table if not exists public.vehicle_colors (
  id          text primary key,
  name_ar     text not null,
  name_en     text not null,
  hex         text not null check (hex ~ '^#[0-9A-Fa-f]{6}$'),
  sort_order  integer not null default 0
);

-- ============================================================================
-- RLS: catalog is read-only reference data for anon + authenticated.
-- ============================================================================
alter table public.vehicle_brands      enable row level security;
alter table public.vehicle_models      enable row level security;
alter table public.vehicle_generations enable row level security;
alter table public.vehicle_trims       enable row level security;
alter table public.vehicle_colors      enable row level security;

do $$ begin
  create policy "vehicle_brands_read" on public.vehicle_brands
    for select to anon, authenticated using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "vehicle_models_read" on public.vehicle_models
    for select to anon, authenticated using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "vehicle_generations_read" on public.vehicle_generations
    for select to anon, authenticated using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "vehicle_trims_read" on public.vehicle_trims
    for select to anon, authenticated using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "vehicle_colors_read" on public.vehicle_colors
    for select to anon, authenticated using (true);
exception when duplicate_object then null; end $$;

revoke insert, update, delete on public.vehicle_brands      from anon, authenticated;
revoke insert, update, delete on public.vehicle_models      from anon, authenticated;
revoke insert, update, delete on public.vehicle_generations from anon, authenticated;
revoke insert, update, delete on public.vehicle_trims       from anon, authenticated;
revoke insert, update, delete on public.vehicle_colors      from anon, authenticated;

grant select on public.vehicle_brands, public.vehicle_models,
  public.vehicle_generations, public.vehicle_trims, public.vehicle_colors
  to anon, authenticated;

commit;
