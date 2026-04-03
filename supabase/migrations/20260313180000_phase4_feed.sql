begin;

create extension if not exists postgis;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'post_type') then
    create type public.post_type as enum ('normal', 'alert', 'prayer', 'story_ref', 'event');
  end if;

  if not exists (select 1 from pg_type where typname = 'post_scope') then
    create type public.post_scope as enum ('world', 'country', 'state', 'city', 'community');
  end if;

  if not exists (select 1 from pg_type where typname = 'post_media_type') then
    create type public.post_media_type as enum ('none', 'image', 'video');
  end if;
end
$$;

alter table public.posts
  add column if not exists scope text not null default 'world';

alter table public.posts
  add column if not exists post_type text not null default 'normal';

alter table public.posts
  add column if not exists media_type text not null default 'none';

update public.posts
set post_type = 'prayer'
where kind = 'request'::public.post_kind
  and post_type = 'normal';

update public.posts
set scope = 'community'
where community_id is not null;

update public.posts p
set scope = case l.level
  when 'city'::public.location_level then 'city'
  when 'state'::public.location_level then 'state'
  when 'country'::public.location_level then 'country'
  when 'world'::public.location_level then 'world'
  else 'world'
end
from public.locations l
where p.community_id is null
  and p.location_id is not null
  and p.location_id = l.id;

update public.posts p
set
  lat = l.center_lat,
  lng = l.center_lng
from public.locations l
where p.location_id is not null
  and p.location_id = l.id
  and p.lat is null
  and p.lng is null
  and l.center_lat is not null
  and l.center_lng is not null;

create or replace function public.derive_post_fields()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_level public.location_level;
begin
  if new.community_id is not null then
    new.scope = 'community';
  elsif new.location_id is not null then
    select level into v_level
    from public.locations
    where id = new.location_id
    limit 1;

    new.scope = case v_level
      when 'city'::public.location_level then 'city'
      when 'state'::public.location_level then 'state'
      when 'country'::public.location_level then 'country'
      when 'world'::public.location_level then 'world'
      else 'world'
    end;
  else
    new.scope = 'world';
  end if;

  if new.kind = 'request'::public.post_kind and coalesce(new.post_type, 'normal') = 'normal' then
    new.post_type = 'prayer';
  elsif new.kind = 'testimony'::public.post_kind and coalesce(new.post_type, 'normal') = 'prayer' then
    new.post_type = 'normal';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_posts_derive_fields on public.posts;
create trigger trg_posts_derive_fields
before insert or update of community_id, location_id, kind, post_type
on public.posts
for each row execute function public.derive_post_fields();

create index if not exists idx_posts_scope_created_at on public.posts (scope, created_at desc);
create index if not exists idx_posts_post_type_created_at on public.posts (post_type, created_at desc);

create or replace function public.get_feed_by_scope(
  p_scope text,
  p_location_id uuid default null,
  p_community_id uuid default null,
  p_post_types text[] default null,
  p_sort text default 'recent',
  p_cursor_created_at timestamptz default null,
  p_limit integer default 24,
  p_lat double precision default null,
  p_lng double precision default null
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
  location_name text,
  scope text,
  post_type text,
  media_type text,
  distance_m double precision
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
  ),
  base as (
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
      ploc.name as location_name,
      p.scope,
      p.post_type,
      p.media_type,
      case
        when p_lat is null or p_lng is null or p.lat is null or p.lng is null then null
        else 6371000::double precision * acos(
          least(
            1::double precision,
            greatest(
              -1::double precision,
              cos(radians(p_lat)) * cos(radians(p.lat)) * cos(radians(p.lng) - radians(p_lng))
              + sin(radians(p_lat)) * sin(radians(p.lat))
            )
          )
        )
      end as distance_m
    from public.posts p
    left join public.locations ploc on ploc.id = p.location_id
    left join target t on true
    where
      (
        (p_scope = 'community' and p_community_id is not null and p.community_id = p_community_id and (
          p_location_id is null
          or (t.path is not null and ploc.path is not null and (
            ploc.path = t.path
            or ploc.path like (t.path || '/%')
          ))
        ))
        or
        (p_scope <> 'community' and t.path is not null and p.community_id is null and ploc.path is not null and (
          ploc.path = t.path
          or ploc.path like (t.path || '/%')
        ))
      )
      and (
        p_post_types is null
        or p.post_type::text = any (p_post_types)
      )
      and (
        p_cursor_created_at is null
        or p.created_at < p_cursor_created_at
      )
  )
  select *
  from base
  order by
    case when p_sort = 'nearby' then distance_m end asc nulls last,
    case when p_sort in ('popular', 'relevance') then (like_count + prayer_count * 2 + comment_count) end desc nulls last,
    created_at desc
  limit greatest(p_limit, 1);
$$;

create or replace function public.get_city_feed(
  p_city_id uuid,
  p_post_types text[] default null,
  p_sort text default 'recent',
  p_cursor_created_at timestamptz default null,
  p_limit integer default 24,
  p_lat double precision default null,
  p_lng double precision default null
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
  location_name text,
  scope text,
  post_type text,
  media_type text,
  distance_m double precision
)
language sql
stable
set search_path = public
as $$
  select *
  from public.get_feed_by_scope(
    'city',
    p_city_id,
    null,
    p_post_types,
    p_sort,
    p_cursor_created_at,
    p_limit,
    p_lat,
    p_lng
  );
$$;

create or replace function public.get_nearby_feed(
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer default 50000,
  p_post_types text[] default null,
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
  location_name text,
  scope text,
  post_type text,
  media_type text,
  distance_m double precision
)
language sql
stable
set search_path = public
as $$
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
    l.path as location_path,
    l.name as location_name,
    p.scope,
    p.post_type,
    p.media_type,
    6371000::double precision * acos(
      least(
        1::double precision,
        greatest(
          -1::double precision,
          cos(radians(p_lat)) * cos(radians(p.lat)) * cos(radians(p.lng) - radians(p_lng))
          + sin(radians(p_lat)) * sin(radians(p.lat))
        )
      )
    ) as distance_m
  from public.posts p
  left join public.locations l on l.id = p.location_id
  where p.community_id is null
    and p.lat is not null
    and p.lng is not null
    and 6371000::double precision * acos(
      least(
        1::double precision,
        greatest(
          -1::double precision,
          cos(radians(p_lat)) * cos(radians(p.lat)) * cos(radians(p.lng) - radians(p_lng))
          + sin(radians(p_lat)) * sin(radians(p.lat))
        )
      )
    ) <= greatest(p_radius_m, 1)
    and (
      p_post_types is null
      or p.post_type::text = any (p_post_types)
    )
  order by distance_m asc, created_at desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.get_feed_by_scope(text, uuid, uuid, text[], text, timestamptz, integer, double precision, double precision) to anon, authenticated;
grant execute on function public.get_city_feed(uuid, text[], text, timestamptz, integer, double precision, double precision) to anon, authenticated;
grant execute on function public.get_nearby_feed(double precision, double precision, integer, text[], integer) to anon, authenticated;

commit;
