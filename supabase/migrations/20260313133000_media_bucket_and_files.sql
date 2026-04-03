begin;

insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

create table if not exists public.media_files (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  url text not null,
  thumbnail text,
  size int,
  duration int,
  created_at timestamptz not null default now()
);

create index if not exists idx_media_files_user_created_at on public.media_files (user_id, created_at desc);

alter table public.media_files enable row level security;

drop policy if exists "media_files_select_own" on public.media_files;
drop policy if exists "media_files_insert_own" on public.media_files;
drop policy if exists "media_files_update_own" on public.media_files;
drop policy if exists "media_files_delete_own" on public.media_files;

create policy "media_files_select_own"
on public.media_files for select
using (auth.uid() = user_id);

create policy "media_files_insert_own"
on public.media_files for insert
with check (auth.uid() = user_id);

create policy "media_files_update_own"
on public.media_files for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "media_files_delete_own"
on public.media_files for delete
using (auth.uid() = user_id);

drop policy if exists "storage_media_select_public" on storage.objects;
drop policy if exists "storage_media_insert_own" on storage.objects;
drop policy if exists "storage_media_update_own" on storage.objects;
drop policy if exists "storage_media_delete_own" on storage.objects;

create policy "storage_media_select_public"
on storage.objects for select
using (bucket_id = 'media');

create policy "storage_media_insert_own"
on storage.objects for insert
with check (bucket_id = 'media' and owner = auth.uid());

create policy "storage_media_update_own"
on storage.objects for update
using (bucket_id = 'media' and owner = auth.uid())
with check (bucket_id = 'media' and owner = auth.uid());

create policy "storage_media_delete_own"
on storage.objects for delete
using (bucket_id = 'media' and owner = auth.uid());

commit;
