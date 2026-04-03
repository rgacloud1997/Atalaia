begin;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'post_type'
  ) then
    create type public.post_type as enum ('normal', 'alert', 'prayer', 'story_ref', 'event');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'post_media_type'
  ) then
    create type public.post_media_type as enum ('none', 'image', 'video');
  end if;
end
$$;

drop trigger if exists trg_posts_derive_fields on public.posts;
drop function if exists public.derive_post_fields();

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'posts' and column_name = 'scope'
  ) then
    execute 'alter table public.posts alter column scope set default ''world''';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'posts' and column_name = 'post_type'
  ) then
    execute 'alter table public.posts alter column post_type set default ''normal''';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'posts' and column_name = 'media_type'
  ) then
    execute 'alter table public.posts alter column media_type set default ''none''';
  end if;
end
$$;

update public.posts
set
  scope = coalesce(nullif(to_jsonb(posts)->>'scope', ''), case when community_id is not null then 'community' else 'world' end),
  post_type = coalesce(nullif(to_jsonb(posts)->>'post_type', ''), case when kind = 'request'::public.post_kind then 'prayer' else 'normal' end),
  media_type = coalesce(nullif(to_jsonb(posts)->>'media_type', ''), 'none')
where
  coalesce(nullif(to_jsonb(posts)->>'scope', ''), '') = ''
  or coalesce(nullif(to_jsonb(posts)->>'post_type', ''), '') = ''
  or coalesce(nullif(to_jsonb(posts)->>'media_type', ''), '') = '';

commit;
