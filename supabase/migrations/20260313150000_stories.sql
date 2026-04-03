begin;

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  city_id uuid not null references public.locations(id) on delete cascade,
  media_url text,
  media_type text not null default 'text',
  text text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint stories_media_type_check check (media_type in ('image', 'video', 'text'))
);

create index if not exists idx_stories_city_expires_at on public.stories (city_id, expires_at desc);
create index if not exists idx_stories_user_created_at on public.stories (user_id, created_at desc);

alter table public.stories enable row level security;

drop policy if exists "stories_select_active" on public.stories;
drop policy if exists "stories_insert_own" on public.stories;
drop policy if exists "stories_update_own" on public.stories;
drop policy if exists "stories_delete_own" on public.stories;

create policy "stories_select_active"
on public.stories for select
using (expires_at > now());

create policy "stories_insert_own"
on public.stories for insert
with check (auth.uid() = user_id);

create policy "stories_update_own"
on public.stories for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "stories_delete_own"
on public.stories for delete
using (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('stories', 'stories', true)
on conflict (id) do nothing;

drop policy if exists "storage_stories_select_public" on storage.objects;
drop policy if exists "storage_stories_insert_own" on storage.objects;
drop policy if exists "storage_stories_update_own" on storage.objects;
drop policy if exists "storage_stories_delete_own" on storage.objects;

create policy "storage_stories_select_public"
on storage.objects for select
using (bucket_id = 'stories');

create policy "storage_stories_insert_own"
on storage.objects for insert
with check (bucket_id = 'stories' and owner = auth.uid());

create policy "storage_stories_update_own"
on storage.objects for update
using (bucket_id = 'stories' and owner = auth.uid())
with check (bucket_id = 'stories' and owner = auth.uid());

create policy "storage_stories_delete_own"
on storage.objects for delete
using (bucket_id = 'stories' and owner = auth.uid());

commit;
