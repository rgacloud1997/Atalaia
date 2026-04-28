begin;

create table if not exists public.prayer_targets (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  description text,
  target_type text not null default 'general',
  icon_emoji text,
  color_hex text,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint prayer_targets_type_check check (target_type in ('nation', 'region', 'group', 'person', 'general'))
);

create index if not exists idx_prayer_targets_community_active
on public.prayer_targets (community_id, is_active);

drop trigger if exists trg_prayer_targets_updated_at on public.prayer_targets;
create trigger trg_prayer_targets_updated_at
before update on public.prayer_targets
for each row execute function public.set_updated_at();

alter table public.prayer_targets enable row level security;

drop policy if exists "prayer_targets_select_members" on public.prayer_targets;
create policy "prayer_targets_select_members"
on public.prayer_targets for select
using (
  public.community_can_view(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "prayer_targets_write_admin" on public.prayer_targets;
create policy "prayer_targets_write_admin"
on public.prayer_targets for all
using (
  public.community_is_admin(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  public.community_is_admin(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

grant select, insert, update, delete on public.prayer_targets to authenticated;

alter table if exists public.community_prayer_schedules
  add column if not exists prayer_target_id uuid references public.prayer_targets(id) on delete set null;

create index if not exists idx_comm_prayer_schedules_prayer_target
on public.community_prayer_schedules (prayer_target_id);

commit;
