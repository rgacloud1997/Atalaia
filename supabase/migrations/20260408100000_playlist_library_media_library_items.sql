begin;

create table if not exists public.media_library_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  subtitle text,
  type text not null,
  media_url text not null,
  thumbnail_url text,
  duration_seconds integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_media_library_items_owner_id on public.media_library_items (owner_id);

create trigger trg_media_library_items_updated_at
before update on public.media_library_items
for each row execute function public.set_updated_at();

alter table public.media_library_items enable row level security;

drop policy if exists "media_library_items_select_own" on public.media_library_items;
create policy "media_library_items_select_own"
on public.media_library_items for select
using (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "media_library_items_insert_own" on public.media_library_items;
create policy "media_library_items_insert_own"
on public.media_library_items for insert
with check (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "media_library_items_update_own" on public.media_library_items;
create policy "media_library_items_update_own"
on public.media_library_items for update
using (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "media_library_items_delete_own" on public.media_library_items;
create policy "media_library_items_delete_own"
on public.media_library_items for delete
using (
  auth.uid() = owner_id
  or coalesce(auth.role(), '') = 'service_role'
);

commit;
