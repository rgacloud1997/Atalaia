begin;

-- Per-user nicknames for direct (dm:...) conversations.
-- This avoids abusing direct_thread_members.nickname (which is per membership row) and supports
-- setting a nickname for the other participant while keeping RLS safe.
create table if not exists public.direct_thread_member_aliases (
  thread_id text not null references public.direct_threads(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  nickname text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (thread_id, owner_id, target_user_id),
  constraint direct_thread_member_aliases_nickname_len_check check (char_length(nickname) between 1 and 64)
);

create index if not exists idx_direct_thread_member_aliases_owner on public.direct_thread_member_aliases (owner_id);
create index if not exists idx_direct_thread_member_aliases_thread on public.direct_thread_member_aliases (thread_id);

alter table public.direct_thread_member_aliases enable row level security;

drop trigger if exists trg_direct_thread_member_aliases_updated_at on public.direct_thread_member_aliases;
create trigger trg_direct_thread_member_aliases_updated_at
before update on public.direct_thread_member_aliases
for each row execute function public.set_updated_at();

-- RLS: only a thread member can manage their own aliases.
drop policy if exists "direct_thread_member_aliases_select_owner" on public.direct_thread_member_aliases;
create policy "direct_thread_member_aliases_select_owner"
on public.direct_thread_member_aliases for select
using (
  owner_id = auth.uid()
  and public.is_direct_thread_member(direct_thread_member_aliases.thread_id, auth.uid())
);

drop policy if exists "direct_thread_member_aliases_insert_owner" on public.direct_thread_member_aliases;
create policy "direct_thread_member_aliases_insert_owner"
on public.direct_thread_member_aliases for insert
with check (
  owner_id = auth.uid()
  and public.is_direct_thread_member(direct_thread_member_aliases.thread_id, auth.uid())
  and public.is_direct_thread_member(direct_thread_member_aliases.thread_id, direct_thread_member_aliases.target_user_id)
);

drop policy if exists "direct_thread_member_aliases_update_owner" on public.direct_thread_member_aliases;
create policy "direct_thread_member_aliases_update_owner"
on public.direct_thread_member_aliases for update
using (
  owner_id = auth.uid()
  and public.is_direct_thread_member(direct_thread_member_aliases.thread_id, auth.uid())
)
with check (
  owner_id = auth.uid()
  and public.is_direct_thread_member(direct_thread_member_aliases.thread_id, auth.uid())
  and public.is_direct_thread_member(direct_thread_member_aliases.thread_id, direct_thread_member_aliases.target_user_id)
);

drop policy if exists "direct_thread_member_aliases_delete_owner" on public.direct_thread_member_aliases;
create policy "direct_thread_member_aliases_delete_owner"
on public.direct_thread_member_aliases for delete
using (
  owner_id = auth.uid()
  and public.is_direct_thread_member(direct_thread_member_aliases.thread_id, auth.uid())
);

grant select, insert, update, delete on public.direct_thread_member_aliases to authenticated;

commit;

