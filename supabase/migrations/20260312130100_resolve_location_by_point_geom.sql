begin;

create or replace function public.resolve_location_by_point_geom(
  p_level public.location_level,
  p_lat double precision,
  p_lng double precision
)
returns table (
  location_id uuid,
  name text,
  level public.location_level,
  path text
)
language sql
stable
set search_path = public
as $$
  select l.id, l.name, l.level, l.path
  from public.locations l
  where l.level = p_level
    and l.geom is not null
    and st_contains(
      l.geom,
      st_setsrid(st_point(p_lng, p_lat), 4326)
    )
  order by st_area(l.geom) asc
  limit 1;
$$;

grant execute on function public.resolve_location_by_point_geom(public.location_level, double precision, double precision) to anon, authenticated;

commit;

