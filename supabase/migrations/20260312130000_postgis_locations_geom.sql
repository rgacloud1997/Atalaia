begin;

create extension if not exists postgis;

alter table public.locations
  add column if not exists geom geometry(MultiPolygon, 4326);

alter table public.locations
  add column if not exists bbox_min_lat double precision;
alter table public.locations
  add column if not exists bbox_min_lng double precision;
alter table public.locations
  add column if not exists bbox_max_lat double precision;
alter table public.locations
  add column if not exists bbox_max_lng double precision;

create index if not exists idx_locations_geom_gist on public.locations using gist (geom);
create index if not exists idx_locations_level_parent on public.locations(level, parent_id);

commit;

