begin;

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
    select l.id, l.path
    from public.locations l
    where l.id = p_location_id
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
      coalesce(
        nullif(to_jsonb(p)->>'scope', ''),
        case
          when p.community_id is not null then 'community'
          when p.location_id is null then 'world'
          else coalesce(ploc.level::text, 'world')
        end
      ) as scope,
      coalesce(nullif(to_jsonb(p)->>'post_type', ''), case when p.kind = 'request' then 'prayer' else 'normal' end) as post_type,
      coalesce(nullif(to_jsonb(p)->>'media_type', ''), 'none') as media_type,
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
        (
          p_scope = 'community'
          and p_community_id is not null
          and p.community_id = p_community_id
          and (
            p_location_id is null
            or (
              t.path is not null
              and ploc.path is not null
              and (
                ploc.path = t.path
                or ploc.path like (t.path || '/%')
              )
            )
          )
        )
        or
        (
          p_scope <> 'community'
          and p.community_id is null
          and (
            p_location_id is null
            or (
              t.path is not null
              and ploc.path is not null
              and (
                ploc.path = t.path
                or ploc.path like (t.path || '/%')
              )
            )
          )
        )
      )
      and (
        p_post_types is null
        or coalesce(nullif(to_jsonb(p)->>'post_type', ''), case when p.kind = 'request' then 'prayer' else 'normal' end) = any (p_post_types)
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

drop trigger if exists trg_posts_derive_fields on public.posts;
drop function if exists public.derive_post_fields();

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'posts' and column_name = 'scope'
  ) then
    alter table public.posts add column scope text;
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'posts' and column_name = 'post_type'
  ) then
    alter table public.posts add column post_type text;
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'posts' and column_name = 'media_type'
  ) then
    alter table public.posts add column media_type text;
  end if;
end
$$;

update public.posts
set
  scope = coalesce(scope, case when community_id is not null then 'community' when location_id is null then 'world' else 'world' end),
  post_type = coalesce(post_type, case when kind = 'request'::public.post_kind then 'prayer' else 'normal' end),
  media_type = coalesce(media_type, 'none')
where scope is null or post_type is null or media_type is null;

commit;
