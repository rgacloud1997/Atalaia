begin;

alter table public.locations_geom_import
  add column if not exists center_lat double precision;

alter table public.locations_geom_import
  add column if not exists center_lng double precision;

alter table public.locations_geom_import
  add column if not exists name text;

alter table public.locations_geom_import
  add column if not exists code text;

commit;
