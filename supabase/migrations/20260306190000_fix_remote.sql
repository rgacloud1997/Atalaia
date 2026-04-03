begin;

create extension if not exists pgcrypto;

alter table public.profiles add column if not exists is_verified boolean;
alter table public.profiles alter column is_verified set default false;
update public.profiles set is_verified = false where is_verified is null;
alter table public.profiles alter column is_verified set not null;

alter table public.profiles add column if not exists verified_type text;
alter table public.profiles add column if not exists verified_since timestamptz;
alter table public.profiles add column if not exists verified_expires_at timestamptz;

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

drop function if exists public.can_view_post(uuid);

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null default 'church',
  is_closed boolean not null default true,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_communities_updated_at on public.communities;
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

alter table public.communities enable row level security;
alter table public.community_members enable row level security;

alter table public.posts add column if not exists community_id uuid references public.communities(id) on delete set null;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_prevent_verified_update on public.profiles;
create trigger trg_profiles_prevent_verified_update
before update on public.profiles
for each row execute function public.prevent_profile_verified_fields_update();

drop policy if exists "profiles_select_public" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_update_service_role" on public.profiles;
drop policy if exists "follows_select_own" on public.follows;
drop policy if exists "follows_insert_own" on public.follows;
drop policy if exists "follows_delete_own" on public.follows;
drop policy if exists "communities_select_visible" on public.communities;
drop policy if exists "communities_insert_own" on public.communities;
drop policy if exists "communities_update_own" on public.communities;
drop policy if exists "communities_delete_own" on public.communities;
drop policy if exists "community_members_select_own_or_owner" on public.community_members;
drop policy if exists "community_members_insert_by_owner" on public.community_members;
drop policy if exists "community_members_update_by_owner" on public.community_members;
drop policy if exists "community_members_delete_own_or_owner" on public.community_members;
drop policy if exists "posts_select_visible" on public.posts;
drop policy if exists "posts_insert_own" on public.posts;
drop policy if exists "posts_update_own" on public.posts;
drop policy if exists "posts_delete_own" on public.posts;
drop policy if exists "post_media_select_if_post_visible" on public.post_media;
drop policy if exists "post_media_insert_if_owner" on public.post_media;
drop policy if exists "post_media_delete_if_owner" on public.post_media;
drop policy if exists "comments_select_if_post_visible" on public.comments;
drop policy if exists "comments_insert_own_if_post_visible" on public.comments;
drop policy if exists "comments_update_own" on public.comments;
drop policy if exists "comments_delete_own" on public.comments;
drop policy if exists "reactions_select_if_post_visible" on public.reactions;
drop policy if exists "reactions_insert_own_if_post_visible" on public.reactions;
drop policy if exists "reactions_delete_own" on public.reactions;
drop policy if exists "prayers_select_if_post_visible" on public.prayers;
drop policy if exists "prayers_insert_own_if_post_visible" on public.prayers;
drop policy if exists "prayers_delete_own" on public.prayers;
drop policy if exists "notifications_select_own" on public.notifications;
drop policy if exists "notifications_update_own" on public.notifications;
drop policy if exists "reports_insert_auth" on public.reports;
drop policy if exists "reports_select_own" on public.reports;
drop policy if exists "locations_select_public" on public.locations;
drop policy if exists "location_aggregates_select_public" on public.location_aggregates;

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
