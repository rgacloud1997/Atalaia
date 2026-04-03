begin;

create or replace function public.map_locations_shapes(
  p_level public.location_level,
  p_parent_id uuid,
  p_limit integer default 250,
  p_simplify_tolerance double precision default 0.35
)
returns table (
  location_id uuid,
  location_name text,
  location_level public.location_level,
  location_path text,
  center_lat double precision,
  center_lng double precision,
  geom_geojson text
)
language sql
stable
set search_path = public
as $$
  select
    l.id,
    l.name,
    l.level,
    l.path,
    l.center_lat,
    l.center_lng,
    st_asgeojson(st_simplifypreservetopology(l.geom, p_simplify_tolerance)) as geom_geojson
  from public.locations l
  where l.level = p_level
    and l.parent_id = p_parent_id
    and l.geom is not null
  order by l.name asc
  limit p_limit;
$$;

grant execute on function public.map_locations_shapes(public.location_level, uuid, integer, double precision) to anon, authenticated;

commit;

