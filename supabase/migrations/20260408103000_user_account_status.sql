begin;

alter table if exists public.profiles
  add column if not exists is_active boolean not null default true,
  add column if not exists deactivated_at timestamptz,
  add column if not exists deleted_at timestamptz;

create index if not exists idx_profiles_is_active on public.profiles (is_active);
create index if not exists idx_profiles_deleted_at on public.profiles (deleted_at);

commit;

