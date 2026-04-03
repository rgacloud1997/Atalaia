begin;

alter table public.locations add column if not exists bbox_min_lat double precision;
alter table public.locations add column if not exists bbox_min_lng double precision;
alter table public.locations add column if not exists bbox_max_lat double precision;
alter table public.locations add column if not exists bbox_max_lng double precision;

create index if not exists idx_locations_level_parent on public.locations(level, parent_id);

do $$
declare
  v_world uuid;
  v_af uuid;
  v_an uuid;
  v_as uuid;
  v_eu uuid;
  v_na uuid;
  v_oc uuid;
  v_sa uuid;
begin
  select id into v_world from public.locations where level = 'world' and code = 'world' limit 1;

  if v_world is not null then
    update public.locations
    set bbox_min_lat = coalesce(bbox_min_lat, -90),
        bbox_min_lng = coalesce(bbox_min_lng, -180),
        bbox_max_lat = coalesce(bbox_max_lat, 90),
        bbox_max_lng = coalesce(bbox_max_lng, 180)
    where id = v_world;
  end if;

  select id into v_sa from public.locations where level = 'continent' and code = 'sa' limit 1;
  if v_sa is not null then
    update public.locations
    set bbox_min_lat = coalesce(bbox_min_lat, -56),
        bbox_min_lng = coalesce(bbox_min_lng, -82),
        bbox_max_lat = coalesce(bbox_max_lat, 13),
        bbox_max_lng = coalesce(bbox_max_lng, -34)
    where id = v_sa;
  end if;

  update public.locations
  set bbox_min_lat = coalesce(bbox_min_lat, -34),
      bbox_min_lng = coalesce(bbox_min_lng, -74),
      bbox_max_lat = coalesce(bbox_max_lat, 6),
      bbox_max_lng = coalesce(bbox_max_lng, -34)
  where level = 'country' and code = 'br';

  update public.locations
  set bbox_min_lat = coalesce(bbox_min_lat, -19.5),
      bbox_min_lng = coalesce(bbox_min_lng, -53.3),
      bbox_max_lat = coalesce(bbox_max_lat, -12.4),
      bbox_max_lng = coalesce(bbox_max_lng, -45.9)
  where level = 'state' and code = 'go';

  update public.locations
  set bbox_min_lat = coalesce(bbox_min_lat, -25.4),
      bbox_min_lng = coalesce(bbox_min_lng, -53.1),
      bbox_max_lat = coalesce(bbox_max_lat, -19.7),
      bbox_max_lng = coalesce(bbox_max_lng, -44.1)
  where level = 'state' and code = 'sp';

  select id into v_af from public.locations where level = 'continent' and code = 'af' limit 1;
  if v_af is null and v_world is not null then
    insert into public.locations (
      level, parent_id, code, name, center_lat, center_lng, path,
      bbox_min_lat, bbox_min_lng, bbox_max_lat, bbox_max_lng
    )
    values (
      'continent', v_world, 'af', 'África', 1.2, 17.3, 'world/af',
      -35, -18, 37, 52
    )
    returning id into v_af;
  end if;

  select id into v_eu from public.locations where level = 'continent' and code = 'eu' limit 1;
  if v_eu is null and v_world is not null then
    insert into public.locations (
      level, parent_id, code, name, center_lat, center_lng, path,
      bbox_min_lat, bbox_min_lng, bbox_max_lat, bbox_max_lng
    )
    values (
      'continent', v_world, 'eu', 'Europa', 54.5, 15.3, 'world/eu',
      35, -25, 72, 45
    )
    returning id into v_eu;
  end if;

  select id into v_as from public.locations where level = 'continent' and code = 'as' limit 1;
  if v_as is null and v_world is not null then
    insert into public.locations (
      level, parent_id, code, name, center_lat, center_lng, path,
      bbox_min_lat, bbox_min_lng, bbox_max_lat, bbox_max_lng
    )
    values (
      'continent', v_world, 'as', 'Ásia', 34.0, 100.0, 'world/as',
      -10, 25, 80, 180
    )
    returning id into v_as;
  end if;

  select id into v_na from public.locations where level = 'continent' and code = 'na' limit 1;
  if v_na is null and v_world is not null then
    insert into public.locations (
      level, parent_id, code, name, center_lat, center_lng, path,
      bbox_min_lat, bbox_min_lng, bbox_max_lat, bbox_max_lng
    )
    values (
      'continent', v_world, 'na', 'América do Norte', 45.0, -100.0, 'world/na',
      7, -168, 83, -52
    )
    returning id into v_na;
  end if;

  select id into v_oc from public.locations where level = 'continent' and code = 'oc' limit 1;
  if v_oc is null and v_world is not null then
    insert into public.locations (
      level, parent_id, code, name, center_lat, center_lng, path,
      bbox_min_lat, bbox_min_lng, bbox_max_lat, bbox_max_lng
    )
    values (
      'continent', v_world, 'oc', 'Oceania', -22.7, 140.5, 'world/oc',
      -50, 110, 0, 180
    )
    returning id into v_oc;
  end if;

  select id into v_an from public.locations where level = 'continent' and code = 'an' limit 1;
  if v_an is null and v_world is not null then
    insert into public.locations (
      level, parent_id, code, name, center_lat, center_lng, path,
      bbox_min_lat, bbox_min_lng, bbox_max_lat, bbox_max_lng
    )
    values (
      'continent', v_world, 'an', 'Antártida', -82.0, 0.0, 'world/an',
      -90, -180, -60, 180
    )
    returning id into v_an;
  end if;
end;
$$;

do $$
declare
  r record;
begin
  for r in
    select (p.oid::regprocedure) as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'resolve_location_by_point'
  loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
end;
$$;

create or replace function public.resolve_location_by_point(
  p_level public.location_level,
  p_lat double precision,
  p_lng double precision
)
returns table (
  location_id uuid,
  name text,
  level public.location_level
)
language sql
stable
set search_path = public
as $$
  select l.id as location_id, l.name, l.level
  from public.locations l
  where l.level = p_level
    and l.bbox_min_lat is not null
    and l.bbox_min_lng is not null
    and l.bbox_max_lat is not null
    and l.bbox_max_lng is not null
    and p_lat between l.bbox_min_lat and l.bbox_max_lat
    and p_lng between l.bbox_min_lng and l.bbox_max_lng
  order by ((l.bbox_max_lat - l.bbox_min_lat) * (l.bbox_max_lng - l.bbox_min_lng)) asc
  limit 1;
$$;

grant execute on function public.resolve_location_by_point(public.location_level, double precision, double precision) to anon, authenticated;

commit;
