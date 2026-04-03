begin;

create table if not exists public.locations_geom_import (
  path text primary key,
  geom_wkt text not null,
  bbox_min_lat double precision,
  bbox_min_lng double precision,
  bbox_max_lat double precision,
  bbox_max_lng double precision
);

commit;

