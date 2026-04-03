begin;

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'post_kind') then
    create type public.post_kind as enum ('request', 'testimony');
  end if;

  if not exists (select 1 from pg_type where typname = 'post_visibility') then
    create type public.post_visibility as enum ('public', 'followers', 'church');
  end if;

  if not exists (select 1 from pg_type where typname = 'media_kind') then
    create type public.media_kind as enum ('image', 'video');
  end if;

  if not exists (select 1 from pg_type where typname = 'media_provider') then
    create type public.media_provider as enum ('supabase', 'mux', 'cloudflare', 'external');
  end if;

  if not exists (select 1 from pg_type where typname = 'notification_kind') then
    create type public.notification_kind as enum ('prayed', 'commented', 'liked', 'followed', 'mentioned');
  end if;

  if not exists (select 1 from pg_type where typname = 'report_target_kind') then
    create type public.report_target_kind as enum ('post', 'comment', 'user');
  end if;

  if not exists (select 1 from pg_type where typname = 'location_level') then
    create type public.location_level as enum ('world', 'continent', 'country', 'state', 'city');
  end if;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  bio text,
  avatar_url text,
  church_id uuid,
  is_verified boolean not null default false,
  verified_type text,
  verified_since timestamptz,
  verified_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.prevent_profile_verified_fields_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (old.is_verified is distinct from new.is_verified)
     or (old.verified_type is distinct from new.verified_type)
     or (old.verified_since is distinct from new.verified_since)
     or (old.verified_expires_at is distinct from new.verified_expires_at) then
    if coalesce(auth.role(), '') <> 'service_role' then
      raise exception 'verified fields can only be updated server-side';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger trg_profiles_prevent_verified_update
before update on public.profiles
for each row execute function public.prevent_profile_verified_fields_update();

create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_not_self check (follower_id <> following_id)
);

create index if not exists idx_follows_following_id on public.follows (following_id);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  level public.location_level not null,
  parent_id uuid references public.locations(id) on delete restrict,
  code text,
  name text not null,
  center_lat double precision,
  center_lng double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint locations_code_unique unique (level, code)
);

create index if not exists idx_locations_parent_id on public.locations(parent_id);
create index if not exists idx_locations_level on public.locations(level);

create trigger trg_locations_updated_at
before update on public.locations
for each row execute function public.set_updated_at();

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null default 'church',
  is_closed boolean not null default true,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_communities_updated_at
before update on public.communities
for each row execute function public.set_updated_at();

create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

create index if not exists idx_community_members_user_id on public.community_members (user_id);
create index if not exists idx_community_members_community_id on public.community_members (community_id);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind public.post_kind not null,
  visibility public.post_visibility not null default 'public',
  is_anonymous boolean not null default false,
  church_id uuid,
  community_id uuid references public.communities(id) on delete set null,
  body text,
  tags text[] not null default '{}'::text[],
  location_id uuid references public.locations(id) on delete set null,
  lat double precision,
  lng double precision,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  prayer_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_posts_user_created_at on public.posts (user_id, created_at desc);
create index if not exists idx_posts_created_at on public.posts (created_at desc);
create index if not exists idx_posts_location_id_created_at on public.posts (location_id, created_at desc);
create index if not exists idx_posts_visibility_created_at on public.posts (visibility, created_at desc);
create index if not exists idx_posts_community_id_created_at on public.posts (community_id, created_at desc);
create index if not exists idx_posts_tags_gin on public.posts using gin (tags);

create trigger trg_posts_updated_at
before update on public.posts
for each row execute function public.set_updated_at();

create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  kind public.media_kind not null,
  provider public.media_provider not null default 'supabase',
  storage_key text,
  external_id text,
  mime_type text,
  size_bytes bigint,
  width integer,
  height integer,
  duration_ms integer,
  order_index integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_post_media_post_id on public.post_media(post_id, order_index);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_comments_post_id_created_at on public.comments (post_id, created_at asc);
create index if not exists idx_comments_user_id on public.comments (user_id);

create trigger trg_comments_updated_at
before update on public.comments
for each row execute function public.set_updated_at();

create table if not exists public.reactions (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists idx_reactions_user_id on public.reactions (user_id);

create table if not exists public.prayers (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  message text,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists idx_prayers_user_id on public.prayers (user_id);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  kind public.notification_kind not null,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_id_created_at on public.notifications (user_id, created_at desc);
create index if not exists idx_notifications_user_id_read_at on public.notifications (user_id, read_at);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_kind public.report_target_kind not null,
  target_id uuid not null,
  reason text not null,
  details text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_reports_target on public.reports (target_kind, target_id);
create index if not exists idx_reports_status on public.reports (status);

create trigger trg_reports_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

create table if not exists public.location_aggregates (
  location_id uuid primary key references public.locations(id) on delete cascade,
  active_requests_count integer not null default 0,
  prayers_count bigint not null default 0,
  posts_last_7d_count integer not null default 0,
  updated_at timestamptz not null default now()
);

create trigger trg_location_aggregates_updated_at
before update on public.location_aggregates
for each row execute function public.set_updated_at();

create or replace function public.increment_post_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'comments' then
    update public.posts set comment_count = comment_count + 1 where id = new.post_id;
  elsif tg_table_name = 'reactions' then
    update public.posts set like_count = like_count + 1 where id = new.post_id;
  elsif tg_table_name = 'prayers' then
    update public.posts set prayer_count = prayer_count + 1 where id = new.post_id;
  end if;
  return new;
end;
$$;

create or replace function public.decrement_post_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'comments' then
    update public.posts set comment_count = greatest(comment_count - 1, 0) where id = old.post_id;
  elsif tg_table_name = 'reactions' then
    update public.posts set like_count = greatest(like_count - 1, 0) where id = old.post_id;
  elsif tg_table_name = 'prayers' then
    update public.posts set prayer_count = greatest(prayer_count - 1, 0) where id = old.post_id;
  end if;
  return old;
end;
$$;

create trigger trg_comments_inc
after insert on public.comments
for each row execute function public.increment_post_counts();

create trigger trg_comments_dec
after delete on public.comments
for each row execute function public.decrement_post_counts();

create trigger trg_reactions_inc
after insert on public.reactions
for each row execute function public.increment_post_counts();

create trigger trg_reactions_dec
after delete on public.reactions
for each row execute function public.decrement_post_counts();

create trigger trg_prayers_inc
after insert on public.prayers
for each row execute function public.increment_post_counts();

create trigger trg_prayers_dec
after delete on public.prayers
for each row execute function public.decrement_post_counts();

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;
alter table public.prayers enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;
alter table public.locations enable row level security;
alter table public.location_aggregates enable row level security;

create policy "profiles_select_public"
on public.profiles for select
using (true);

create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "profiles_update_service_role"
on public.profiles for update
using (coalesce(auth.role(), '') = 'service_role')
with check (coalesce(auth.role(), '') = 'service_role');

create policy "follows_select_own"
on public.follows for select
using (auth.uid() = follower_id or auth.uid() = following_id);

create policy "follows_insert_own"
on public.follows for insert
with check (auth.uid() = follower_id);

create policy "follows_delete_own"
on public.follows for delete
using (auth.uid() = follower_id);

create policy "communities_select_visible"
on public.communities for select
using (
  not is_closed
  or owner_id = auth.uid()
  or coalesce(auth.role(), '') = 'service_role'
);

create policy "communities_insert_own"
on public.communities for insert
with check (owner_id = auth.uid());

create policy "communities_update_own"
on public.communities for update
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "communities_delete_own"
on public.communities for delete
using (owner_id = auth.uid());

create policy "community_members_select_own_or_owner"
on public.community_members for select
using (
  user_id = auth.uid()
  or coalesce(auth.role(), '') = 'service_role'
);

create policy "community_members_insert_by_owner"
on public.community_members for insert
with check (
  exists (
    select 1
    from public.communities c
    where c.id = community_members.community_id
      and c.owner_id = auth.uid()
  )
);

create policy "community_members_update_by_owner"
on public.community_members for update
using (
  exists (
    select 1
    from public.communities c
    where c.id = community_members.community_id
      and c.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.communities c
    where c.id = community_members.community_id
      and c.owner_id = auth.uid()
  )
);

create policy "community_members_delete_own_or_owner"
on public.community_members for delete
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.communities c
    where c.id = community_members.community_id
      and c.owner_id = auth.uid()
  )
);

create policy "posts_select_visible"
on public.posts for select
using (
  (
    posts.community_id is null
    and (
      posts.user_id = auth.uid()
      or posts.visibility = 'public'
      or (
        posts.visibility = 'followers'
        and auth.uid() is not null
        and exists (
          select 1
          from public.follows f
          where f.follower_id = auth.uid()
            and f.following_id = posts.user_id
        )
      )
      or (
        posts.visibility = 'church'
        and auth.uid() is not null
        and posts.church_id is not null
        and exists (
          select 1
          from public.profiles pr
          where pr.id = auth.uid()
            and pr.church_id = posts.church_id
        )
      )
    )
  )
  or (
    posts.community_id is not null
    and auth.uid() is not null
    and (
      exists (
        select 1
        from public.communities c
        where c.id = posts.community_id
          and c.owner_id = auth.uid()
      )
      or exists (
        select 1
        from public.community_members cm
        where cm.community_id = posts.community_id
          and cm.user_id = auth.uid()
          and cm.status = 'active'
      )
    )
    and (
      posts.user_id = auth.uid()
      or posts.visibility = 'public'
      or (
        posts.visibility = 'followers'
        and exists (
          select 1
          from public.follows f
          where f.follower_id = auth.uid()
            and f.following_id = posts.user_id
        )
      )
      or (
        posts.visibility = 'church'
        and posts.church_id is not null
        and exists (
          select 1
          from public.profiles pr
          where pr.id = auth.uid()
            and pr.church_id = posts.church_id
        )
      )
    )
  )
);

create policy "posts_insert_own"
on public.posts for insert
with check (
  auth.uid() = user_id
  and (
    community_id is null
    or exists (
      select 1
      from public.communities c
      where c.id = posts.community_id
        and c.owner_id = auth.uid()
    )
    or exists (
      select 1
      from public.community_members cm
      where cm.community_id = posts.community_id
        and cm.user_id = auth.uid()
        and cm.status = 'active'
    )
  )
);

create policy "posts_update_own"
on public.posts for update
using (auth.uid() = user_id)
with check (
  auth.uid() = user_id
  and (
    community_id is null
    or exists (
      select 1
      from public.communities c
      where c.id = posts.community_id
        and c.owner_id = auth.uid()
    )
    or exists (
      select 1
      from public.community_members cm
      where cm.community_id = posts.community_id
        and cm.user_id = auth.uid()
        and cm.status = 'active'
    )
  )
);

create policy "posts_delete_own"
on public.posts for delete
using (auth.uid() = user_id);

create policy "post_media_select_if_post_visible"
on public.post_media for select
using (exists (
  select 1
  from public.posts p
  where p.id = post_media.post_id
    and (
      (
        p.community_id is null
        and (
          p.user_id = auth.uid()
          or p.visibility = 'public'
          or (
            p.visibility = 'followers'
            and auth.uid() is not null
            and exists (
              select 1
              from public.follows f
              where f.follower_id = auth.uid()
                and f.following_id = p.user_id
            )
          )
          or (
            p.visibility = 'church'
            and auth.uid() is not null
            and p.church_id is not null
            and exists (
              select 1
              from public.profiles pr
              where pr.id = auth.uid()
                and pr.church_id = p.church_id
            )
          )
        )
      )
      or (
        p.community_id is not null
        and auth.uid() is not null
        and (
          exists (
            select 1
            from public.communities c
            where c.id = p.community_id
              and c.owner_id = auth.uid()
          )
          or exists (
            select 1
            from public.community_members cm
            where cm.community_id = p.community_id
              and cm.user_id = auth.uid()
              and cm.status = 'active'
          )
        )
        and (
          p.user_id = auth.uid()
          or p.visibility = 'public'
          or (
            p.visibility = 'followers'
            and exists (
              select 1
              from public.follows f
              where f.follower_id = auth.uid()
                and f.following_id = p.user_id
            )
          )
          or (
            p.visibility = 'church'
            and p.church_id is not null
            and exists (
              select 1
              from public.profiles pr
              where pr.id = auth.uid()
                and pr.church_id = p.church_id
            )
          )
        )
      )
    )
));

create policy "post_media_insert_if_owner"
on public.post_media for insert
with check (exists (
  select 1
  from public.posts p
  where p.id = post_media.post_id
    and p.user_id = auth.uid()
));

create policy "post_media_delete_if_owner"
on public.post_media for delete
using (exists (
  select 1
  from public.posts p
  where p.id = post_media.post_id
    and p.user_id = auth.uid()
));

create policy "comments_select_if_post_visible"
on public.comments for select
using (
  exists (
    select 1
    from public.posts p
    where p.id = comments.post_id
      and (
        (
          p.community_id is null
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and auth.uid() is not null
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and auth.uid() is not null
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
        or (
          p.community_id is not null
          and auth.uid() is not null
          and (
            exists (
              select 1
              from public.communities c
              where c.id = p.community_id
                and c.owner_id = auth.uid()
            )
            or exists (
              select 1
              from public.community_members cm
              where cm.community_id = p.community_id
                and cm.user_id = auth.uid()
                and cm.status = 'active'
            )
          )
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
      )
  )
);

create policy "comments_insert_own_if_post_visible"
on public.comments for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.posts p
    where p.id = comments.post_id
      and (
        (
          p.community_id is null
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and auth.uid() is not null
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and auth.uid() is not null
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
        or (
          p.community_id is not null
          and auth.uid() is not null
          and (
            exists (
              select 1
              from public.communities c
              where c.id = p.community_id
                and c.owner_id = auth.uid()
            )
            or exists (
              select 1
              from public.community_members cm
              where cm.community_id = p.community_id
                and cm.user_id = auth.uid()
                and cm.status = 'active'
            )
          )
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
      )
  )
);

create policy "comments_update_own"
on public.comments for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "comments_delete_own"
on public.comments for delete
using (auth.uid() = user_id);

create policy "reactions_select_if_post_visible"
on public.reactions for select
using (
  exists (
    select 1
    from public.posts p
    where p.id = reactions.post_id
      and (
        (
          p.community_id is null
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and auth.uid() is not null
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and auth.uid() is not null
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
        or (
          p.community_id is not null
          and auth.uid() is not null
          and (
            exists (
              select 1
              from public.communities c
              where c.id = p.community_id
                and c.owner_id = auth.uid()
            )
            or exists (
              select 1
              from public.community_members cm
              where cm.community_id = p.community_id
                and cm.user_id = auth.uid()
                and cm.status = 'active'
            )
          )
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
      )
  )
);

create policy "reactions_insert_own_if_post_visible"
on public.reactions for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.posts p
    where p.id = reactions.post_id
      and (
        (
          p.community_id is null
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and auth.uid() is not null
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and auth.uid() is not null
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
        or (
          p.community_id is not null
          and auth.uid() is not null
          and (
            exists (
              select 1
              from public.communities c
              where c.id = p.community_id
                and c.owner_id = auth.uid()
            )
            or exists (
              select 1
              from public.community_members cm
              where cm.community_id = p.community_id
                and cm.user_id = auth.uid()
                and cm.status = 'active'
            )
          )
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
      )
  )
);

create policy "reactions_delete_own"
on public.reactions for delete
using (auth.uid() = user_id);

create policy "prayers_select_if_post_visible"
on public.prayers for select
using (
  exists (
    select 1
    from public.posts p
    where p.id = prayers.post_id
      and (
        (
          p.community_id is null
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and auth.uid() is not null
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and auth.uid() is not null
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
        or (
          p.community_id is not null
          and auth.uid() is not null
          and (
            exists (
              select 1
              from public.communities c
              where c.id = p.community_id
                and c.owner_id = auth.uid()
            )
            or exists (
              select 1
              from public.community_members cm
              where cm.community_id = p.community_id
                and cm.user_id = auth.uid()
                and cm.status = 'active'
            )
          )
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
      )
  )
);

create policy "prayers_insert_own_if_post_visible"
on public.prayers for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.posts p
    where p.id = prayers.post_id
      and (
        (
          p.community_id is null
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and auth.uid() is not null
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and auth.uid() is not null
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
        or (
          p.community_id is not null
          and auth.uid() is not null
          and (
            exists (
              select 1
              from public.communities c
              where c.id = p.community_id
                and c.owner_id = auth.uid()
            )
            or exists (
              select 1
              from public.community_members cm
              where cm.community_id = p.community_id
                and cm.user_id = auth.uid()
                and cm.status = 'active'
            )
          )
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
      )
  )
);

create policy "prayers_delete_own"
on public.prayers for delete
using (auth.uid() = user_id);

create policy "notifications_select_own"
on public.notifications for select
using (auth.uid() = user_id);

create policy "notifications_update_own"
on public.notifications for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "reports_insert_auth"
on public.reports for insert
with check (auth.uid() = reporter_id);

create policy "reports_select_own"
on public.reports for select
using (auth.uid() = reporter_id);

create policy "locations_select_public"
on public.locations for select
using (true);

create policy "location_aggregates_select_public"
on public.location_aggregates for select
using (true);

commit;
