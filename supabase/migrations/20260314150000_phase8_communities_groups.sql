begin;

alter table if exists public.communities
  add column if not exists description text,
  add column if not exists image_url text,
  add column if not exists location_id uuid references public.locations(id) on delete set null,
  add column if not exists visibility text not null default 'public',
  add column if not exists join_mode text not null default 'request',
  add column if not exists creator_id uuid references auth.users(id) on delete set null;

create or replace function public.community_is_admin(p_community_id uuid, p_user_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    exists (
      select 1
      from public.communities c
      where c.id = p_community_id
        and c.owner_id = p_user_id
    )
    or exists (
      select 1
      from public.community_members cm
      where cm.community_id = p_community_id
        and cm.user_id = p_user_id
        and cm.status = 'active'
        and cm.role in ('admin', 'moderator', 'founder')
    );
$$;

create or replace function public.community_can_view(p_community_id uuid, p_user_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    exists (
      select 1
      from public.communities c
      where c.id = p_community_id
        and (
          c.visibility = 'public'
          or c.owner_id = p_user_id
          or public.community_is_admin(p_community_id, p_user_id)
          or exists (
            select 1
            from public.community_members cm
            where cm.community_id = p_community_id
              and cm.user_id = p_user_id
              and cm.status = 'active'
          )
        )
    );
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'communities'
      and column_name = 'creator_id'
  ) then
    update public.communities
    set creator_id = owner_id
    where creator_id is null;
  end if;
end $$;

create or replace function public.sync_community_creator_id()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.creator_id is null then
    new.creator_id := new.owner_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_communities_creator_id on public.communities;
create trigger trg_communities_creator_id
before insert or update on public.communities
for each row execute function public.sync_community_creator_id();

alter table if exists public.communities
  drop constraint if exists communities_visibility_check,
  add constraint communities_visibility_check check (visibility in ('public', 'private', 'unlisted')) not valid;

alter table if exists public.communities
  drop constraint if exists communities_join_mode_check,
  add constraint communities_join_mode_check check (join_mode in ('public', 'request', 'invite')) not valid;

alter table if exists public.community_members
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists joined_at timestamptz not null default now();

update public.community_members
set joined_at = created_at
where joined_at is null;

alter table if exists public.community_members
  drop constraint if exists community_members_role_check,
  add constraint community_members_role_check check (role in ('member', 'moderator', 'admin', 'founder')) not valid;

alter table if exists public.community_members
  drop constraint if exists community_members_status_check,
  add constraint community_members_status_check check (status in ('active', 'pending', 'invited', 'banned')) not valid;

create index if not exists idx_community_members_status on public.community_members (community_id, status);
create unique index if not exists idx_community_members_id_unique on public.community_members (id);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  description text,
  location text,
  start_time timestamptz not null,
  end_time timestamptz,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_events_community_start_time on public.events (community_id, start_time asc);

drop trigger if exists trg_events_updated_at on public.events;
create trigger trg_events_updated_at
before update on public.events
for each row execute function public.set_updated_at();

create table if not exists public.community_messages (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_community_messages_community_created_at on public.community_messages (community_id, created_at desc);
create index if not exists idx_community_messages_user_id on public.community_messages (user_id);

alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.events enable row level security;
alter table public.community_messages enable row level security;

drop policy if exists "communities_select_visible" on public.communities;
create policy "communities_select_visible"
on public.communities for select
using (
  visibility = 'public'
  or owner_id = auth.uid()
  or public.community_is_admin(id, auth.uid())
  or exists (
    select 1
    from public.community_members cm
    where cm.community_id = communities.id
      and cm.user_id = auth.uid()
      and cm.status = 'active'
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "communities_insert_own" on public.communities;
create policy "communities_insert_own"
on public.communities for insert
with check (
  owner_id = auth.uid()
  and creator_id = auth.uid()
);

drop policy if exists "communities_update_own" on public.communities;
create policy "communities_update_own"
on public.communities for update
using (
  owner_id = auth.uid()
  or public.community_is_admin(id, auth.uid())
)
with check (
  owner_id = auth.uid()
  or public.community_is_admin(id, auth.uid())
);

drop policy if exists "communities_delete_own" on public.communities;
create policy "communities_delete_own"
on public.communities for delete
using (
  owner_id = auth.uid()
  or public.community_is_admin(id, auth.uid())
);

drop policy if exists "community_members_select_own_or_admin" on public.community_members;
drop policy if exists "community_members_select_own_or_owner" on public.community_members;
create policy "community_members_select_own_or_admin"
on public.community_members for select
using (
  user_id = auth.uid()
  or public.community_is_admin(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "community_members_insert_self" on public.community_members;
drop policy if exists "community_members_insert_by_owner" on public.community_members;
create policy "community_members_insert_self"
on public.community_members for insert
with check (
  auth.uid() = user_id
  and role = 'member'
  and (
    (
      status = 'active'
      and exists (
        select 1
        from public.communities c
        where c.id = community_members.community_id
          and c.join_mode = 'public'
      )
    )
    or (
      status = 'pending'
      and exists (
        select 1
        from public.communities c
        where c.id = community_members.community_id
          and c.join_mode = 'request'
      )
    )
  )
);

drop policy if exists "community_members_insert_by_admin" on public.community_members;
create policy "community_members_insert_by_admin"
on public.community_members for insert
with check (
  public.community_is_admin(community_id, auth.uid())
);

drop policy if exists "community_members_update_by_admin" on public.community_members;
drop policy if exists "community_members_update_by_owner" on public.community_members;
create policy "community_members_update_by_admin"
on public.community_members for update
using (
  public.community_is_admin(community_id, auth.uid())
)
with check (
  public.community_is_admin(community_id, auth.uid())
);

drop policy if exists "community_members_update_self_accept_invite" on public.community_members;
create policy "community_members_update_self_accept_invite"
on public.community_members for update
using (
  user_id = auth.uid()
  and status = 'invited'
)
with check (
  user_id = auth.uid()
  and status = 'active'
  and role = 'member'
);

drop policy if exists "community_members_delete_own_or_admin" on public.community_members;
drop policy if exists "community_members_delete_own_or_owner" on public.community_members;
create policy "community_members_delete_own_or_admin"
on public.community_members for delete
using (
  user_id = auth.uid()
  or public.community_is_admin(community_id, auth.uid())
);

drop policy if exists "events_select_if_can_view" on public.events;
create policy "events_select_if_can_view"
on public.events for select
using (public.community_can_view(community_id, auth.uid()));

drop policy if exists "events_insert_if_member" on public.events;
create policy "events_insert_if_member"
on public.events for insert
with check (
  auth.uid() = created_by
  and (
    public.community_is_admin(community_id, auth.uid())
    or exists (
      select 1
      from public.community_members cm
      where cm.community_id = events.community_id
        and cm.user_id = auth.uid()
        and cm.status = 'active'
    )
  )
);

drop policy if exists "events_update_if_creator_or_admin" on public.events;
create policy "events_update_if_creator_or_admin"
on public.events for update
using (
  created_by = auth.uid()
  or public.community_is_admin(community_id, auth.uid())
)
with check (
  created_by = auth.uid()
  or public.community_is_admin(community_id, auth.uid())
);

drop policy if exists "events_delete_if_creator_or_admin" on public.events;
create policy "events_delete_if_creator_or_admin"
on public.events for delete
using (
  created_by = auth.uid()
  or public.community_is_admin(community_id, auth.uid())
);

drop policy if exists "community_messages_select_if_member" on public.community_messages;
create policy "community_messages_select_if_member"
on public.community_messages for select
using (
  exists (
    select 1
    from public.community_members cm
    where cm.community_id = community_messages.community_id
      and cm.user_id = auth.uid()
      and cm.status = 'active'
  )
  or public.community_is_admin(community_id, auth.uid())
);

drop policy if exists "community_messages_insert_if_member" on public.community_messages;
create policy "community_messages_insert_if_member"
on public.community_messages for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.community_members cm
    where cm.community_id = community_messages.community_id
      and cm.user_id = auth.uid()
      and cm.status = 'active'
  )
);

commit;
