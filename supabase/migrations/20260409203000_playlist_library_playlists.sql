begin;

create table if not exists public.playlists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text not null default '',
  cover_url text,
  visibility text not null default 'public',
  community_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_playlists_owner_id_updated_at on public.playlists (owner_id, updated_at desc);
create index if not exists idx_playlists_visibility_updated_at on public.playlists (visibility, updated_at desc);
create index if not exists idx_playlists_community_id_updated_at on public.playlists (community_id, updated_at desc);

create trigger trg_playlists_updated_at
before update on public.playlists
for each row execute function public.set_updated_at();

create table if not exists public.playlist_items (
  id uuid primary key default gen_random_uuid(),
  playlist_id uuid not null references public.playlists(id) on delete cascade,
  media_item_id uuid,
  title text not null,
  subtitle text,
  type text not null,
  media_url text not null,
  thumbnail_url text,
  duration_seconds integer,
  position integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if to_regclass('public.media_library_items') is not null then
    if not exists (
      select 1
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relname = 'playlist_items'
        and c.conname = 'fk_playlist_items_media_item_id'
    ) then
      alter table public.playlist_items
        add constraint fk_playlist_items_media_item_id
        foreign key (media_item_id)
        references public.media_library_items(id)
        on delete set null;
    end if;
  end if;
end;
$$;

create unique index if not exists uq_playlist_items_playlist_position on public.playlist_items (playlist_id, position);
create index if not exists idx_playlist_items_playlist_id_position on public.playlist_items (playlist_id, position);

create trigger trg_playlist_items_updated_at
before update on public.playlist_items
for each row execute function public.set_updated_at();

create or replace function public.touch_playlist_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  v_id := coalesce(new.playlist_id, old.playlist_id);
  if v_id is null then
    return null;
  end if;
  update public.playlists
  set updated_at = now()
  where id = v_id;
  return null;
end;
$$;

drop trigger if exists trg_playlist_items_touch_playlist on public.playlist_items;
create trigger trg_playlist_items_touch_playlist
after insert or update or delete on public.playlist_items
for each row execute function public.touch_playlist_updated_at();

alter table public.playlists enable row level security;
alter table public.playlist_items enable row level security;

drop policy if exists "playlists_select_own" on public.playlists;
create policy "playlists_select_own"
on public.playlists for select
using (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "playlists_insert_own" on public.playlists;
create policy "playlists_insert_own"
on public.playlists for insert
with check (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "playlists_update_own" on public.playlists;
create policy "playlists_update_own"
on public.playlists for update
using (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "playlists_delete_own" on public.playlists;
create policy "playlists_delete_own"
on public.playlists for delete
using (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "playlist_items_select_own_playlist" on public.playlist_items;
create policy "playlist_items_select_own_playlist"
on public.playlist_items for select
using (
  exists (
    select 1
    from public.playlists p
    where p.id = playlist_id
      and (p.owner_id = auth.uid() or coalesce(auth.role(), '') = 'service_role')
  )
);

drop policy if exists "playlist_items_insert_own_playlist" on public.playlist_items;
create policy "playlist_items_insert_own_playlist"
on public.playlist_items for insert
with check (
  exists (
    select 1
    from public.playlists p
    where p.id = playlist_id
      and (p.owner_id = auth.uid() or coalesce(auth.role(), '') = 'service_role')
  )
);

drop policy if exists "playlist_items_update_own_playlist" on public.playlist_items;
create policy "playlist_items_update_own_playlist"
on public.playlist_items for update
using (
  exists (
    select 1
    from public.playlists p
    where p.id = playlist_id
      and (p.owner_id = auth.uid() or coalesce(auth.role(), '') = 'service_role')
  )
)
with check (
  exists (
    select 1
    from public.playlists p
    where p.id = playlist_id
      and (p.owner_id = auth.uid() or coalesce(auth.role(), '') = 'service_role')
  )
);

drop policy if exists "playlist_items_delete_own_playlist" on public.playlist_items;
create policy "playlist_items_delete_own_playlist"
on public.playlist_items for delete
using (
  exists (
    select 1
    from public.playlists p
    where p.id = playlist_id
      and (p.owner_id = auth.uid() or coalesce(auth.role(), '') = 'service_role')
  )
);

commit;
