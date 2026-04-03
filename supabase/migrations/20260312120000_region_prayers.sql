begin;

create table if not exists public.region_prayers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete restrict,
  message text null,
  created_at timestamptz not null default now()
);

create index if not exists idx_region_prayers_user_id on public.region_prayers (user_id);
create index if not exists idx_region_prayers_location_id on public.region_prayers (location_id);

alter table public.region_prayers enable row level security;

drop policy if exists "region_prayers_select_own" on public.region_prayers;
create policy "region_prayers_select_own"
on public.region_prayers for select
using (auth.uid() = user_id);

drop policy if exists "region_prayers_insert_own" on public.region_prayers;
create policy "region_prayers_insert_own"
on public.region_prayers for insert
with check (auth.uid() = user_id);

grant select, insert on public.region_prayers to authenticated;

commit;
