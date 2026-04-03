begin;

alter table public.locations add column if not exists path text;

create index if not exists idx_locations_path on public.locations (path);

create unique index if not exists locations_path_unique on public.locations (path) where path is not null;

do $$
declare
  v_world uuid;
  v_sa uuid;
  v_br uuid;
  v_go uuid;
  v_goiania uuid;
  v_sp uuid;
  v_sao_paulo uuid;
begin
  select id into v_world from public.locations where level = 'world' and code = 'world' limit 1;
  if v_world is null then
    insert into public.locations (level, parent_id, code, name, center_lat, center_lng, path)
    values ('world', null, 'world', 'Mundo', 0, 0, 'world')
    returning id into v_world;
  else
    update public.locations
    set parent_id = null,
        name = 'Mundo',
        center_lat = coalesce(center_lat, 0),
        center_lng = coalesce(center_lng, 0),
        path = coalesce(path, 'world')
    where id = v_world;
  end if;

  select id into v_sa from public.locations where level = 'continent' and code = 'sa' limit 1;
  if v_sa is null then
    insert into public.locations (level, parent_id, code, name, center_lat, center_lng, path)
    values ('continent', v_world, 'sa', 'América do Sul', -15.6, -57.8, 'world/sa')
    returning id into v_sa;
  else
    update public.locations
    set parent_id = v_world,
        name = 'América do Sul',
        center_lat = coalesce(center_lat, -15.6),
        center_lng = coalesce(center_lng, -57.8),
        path = coalesce(path, 'world/sa')
    where id = v_sa;
  end if;

  select id into v_br from public.locations where level = 'country' and code = 'br' limit 1;
  if v_br is null then
    insert into public.locations (level, parent_id, code, name, center_lat, center_lng, path)
    values ('country', v_sa, 'br', 'Brasil', -14.2, -51.9, 'world/sa/br')
    returning id into v_br;
  else
    update public.locations
    set parent_id = v_sa,
        name = 'Brasil',
        center_lat = coalesce(center_lat, -14.2),
        center_lng = coalesce(center_lng, -51.9),
        path = coalesce(path, 'world/sa/br')
    where id = v_br;
  end if;

  select id into v_go from public.locations where level = 'state' and code = 'go' limit 1;
  if v_go is null then
    insert into public.locations (level, parent_id, code, name, center_lat, center_lng, path)
    values ('state', v_br, 'go', 'Goiás', -15.9, -49.9, 'world/sa/br/go')
    returning id into v_go;
  else
    update public.locations
    set parent_id = v_br,
        name = 'Goiás',
        center_lat = coalesce(center_lat, -15.9),
        center_lng = coalesce(center_lng, -49.9),
        path = coalesce(path, 'world/sa/br/go')
    where id = v_go;
  end if;

  select id into v_goiania from public.locations where level = 'city' and code = 'goiania' limit 1;
  if v_goiania is null then
    insert into public.locations (level, parent_id, code, name, center_lat, center_lng, path)
    values ('city', v_go, 'goiania', 'Goiânia', -16.6869, -49.2648, 'world/sa/br/go/goiania')
    returning id into v_goiania;
  else
    update public.locations
    set parent_id = v_go,
        name = 'Goiânia',
        center_lat = coalesce(center_lat, -16.6869),
        center_lng = coalesce(center_lng, -49.2648),
        path = coalesce(path, 'world/sa/br/go/goiania')
    where id = v_goiania;
  end if;

  select id into v_sp from public.locations where level = 'state' and code = 'sp' limit 1;
  if v_sp is null then
    insert into public.locations (level, parent_id, code, name, center_lat, center_lng, path)
    values ('state', v_br, 'sp', 'São Paulo', -23.55, -46.63, 'world/sa/br/sp')
    returning id into v_sp;
  else
    update public.locations
    set parent_id = v_br,
        name = 'São Paulo',
        center_lat = coalesce(center_lat, -23.55),
        center_lng = coalesce(center_lng, -46.63),
        path = coalesce(path, 'world/sa/br/sp')
    where id = v_sp;
  end if;

  select id into v_sao_paulo from public.locations where level = 'city' and code = 'sao-paulo' limit 1;
  if v_sao_paulo is null then
    insert into public.locations (level, parent_id, code, name, center_lat, center_lng, path)
    values ('city', v_sp, 'sao-paulo', 'São Paulo', -23.5505, -46.6333, 'world/sa/br/sp/sao-paulo')
    returning id into v_sao_paulo;
  else
    update public.locations
    set parent_id = v_sp,
        name = 'São Paulo',
        center_lat = coalesce(center_lat, -23.5505),
        center_lng = coalesce(center_lng, -46.6333),
        path = coalesce(path, 'world/sa/br/sp/sao-paulo')
    where id = v_sao_paulo;
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
      and p.proname in ('map_locations_aggregate', 'map_posts_by_location')
  loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
end;
$$;

create or replace function public.map_locations_aggregate(
  p_level public.location_level,
  p_parent_id uuid default null,
  p_community_id uuid default null,
  p_limit integer default 200
)
returns table (
  location_id uuid,
  location_path text,
  name text,
  level public.location_level,
  center_lat double precision,
  center_lng double precision,
  posts_count bigint,
  prayers_count bigint
)
language sql
stable
set search_path = public
as $$
  select
    l.id as location_id,
    l.path as location_path,
    l.name,
    l.level,
    l.center_lat,
    l.center_lng,
    coalesce(count(p.id), 0) as posts_count,
    coalesce(sum(p.prayer_count), 0) as prayers_count
  from public.locations l
  left join public.locations ploc
    on l.path is not null
   and ploc.path is not null
   and (
     ploc.path = l.path
     or ploc.path like (l.path || '/%')
   )
  left join public.posts p
    on p.location_id = ploc.id
   and p.kind = 'request'
   and (
     p_community_id is null
     or p.community_id = p_community_id
   )
  where l.level = p_level
    and (
      (p_parent_id is null and l.parent_id is null)
      or l.parent_id = p_parent_id
    )
  group by l.id, l.path, l.name, l.level, l.center_lat, l.center_lng
  order by posts_count desc, prayers_count desc, l.name asc
  limit greatest(p_limit, 1);
$$;

create or replace function public.map_posts_by_location(
  p_location_id uuid,
  p_community_id uuid default null,
  p_cursor_created_at timestamptz default null,
  p_limit integer default 24
)
returns table (
  id uuid,
  user_id uuid,
  kind public.post_kind,
  visibility public.post_visibility,
  body text,
  church_id uuid,
  community_id uuid,
  created_at timestamptz,
  like_count integer,
  comment_count integer,
  prayer_count integer,
  location_id uuid,
  location_path text,
  location_name text
)
language sql
stable
set search_path = public
as $$
  with target as (
    select id, path
    from public.locations
    where id = p_location_id
    limit 1
  )
  select
    p.id,
    p.user_id,
    p.kind,
    p.visibility,
    p.body,
    p.church_id,
    p.community_id,
    p.created_at,
    p.like_count,
    p.comment_count,
    p.prayer_count,
    p.location_id,
    ploc.path as location_path,
    ploc.name as location_name
  from public.posts p
  join public.locations ploc on ploc.id = p.location_id
  join target t on true
  where t.path is not null
    and p.kind = 'request'
    and (
      ploc.path = t.path
      or ploc.path like (t.path || '/%')
    )
    and (
      p_community_id is null
      or p.community_id = p_community_id
    )
    and (
      p_cursor_created_at is null
      or p.created_at < p_cursor_created_at
    )
  order by p.created_at desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.map_locations_aggregate(public.location_level, uuid, uuid, integer) to anon, authenticated;
grant execute on function public.map_posts_by_location(uuid, uuid, timestamptz, integer) to anon, authenticated;

commit;
