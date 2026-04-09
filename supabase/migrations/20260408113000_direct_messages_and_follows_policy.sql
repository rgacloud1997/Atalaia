begin;

create table if not exists public.direct_threads (
  id text primary key,
  kind text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint direct_threads_kind_check check (kind in ('dm', 'group'))
);

alter table public.direct_threads
  drop constraint if exists direct_threads_dm_not_self;

alter table public.direct_threads
  add constraint direct_threads_dm_not_self
  check (
    kind <> 'dm'
    or (
      id like 'dm:%:%'
      and split_part(id, ':', 2) <> split_part(id, ':', 3)
      and split_part(id, ':', 2) <> ''
      and split_part(id, ':', 3) <> ''
    )
  );

create table if not exists public.direct_thread_members (
  thread_id text not null references public.direct_threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create index if not exists idx_direct_thread_members_user_id on public.direct_thread_members (user_id);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id text not null references public.direct_threads(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_direct_messages_thread_created_at on public.direct_messages (thread_id, created_at desc);
create index if not exists idx_direct_messages_sender_id on public.direct_messages (sender_id);

alter table public.direct_threads enable row level security;
alter table public.direct_thread_members enable row level security;
alter table public.direct_messages enable row level security;

drop policy if exists "direct_threads_select_member" on public.direct_threads;
create policy "direct_threads_select_member"
on public.direct_threads for select
using (
  (
    direct_threads.kind = 'dm'
    and auth.uid()::text in (split_part(direct_threads.id, ':', 2), split_part(direct_threads.id, ':', 3))
  )
  or exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = direct_threads.id
      and m.user_id = auth.uid()
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_threads_insert_own" on public.direct_threads;
create policy "direct_threads_insert_own"
on public.direct_threads for insert
with check (
  coalesce(auth.role(), '') in ('authenticated', 'service_role')
  and created_by = auth.uid()
);

drop policy if exists "direct_thread_members_select_member" on public.direct_thread_members;
create policy "direct_thread_members_select_member"
on public.direct_thread_members for select
using (
  user_id = auth.uid()
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_thread_members_insert_by_creator" on public.direct_thread_members;
drop policy if exists "direct_thread_members_insert_dm_participant" on public.direct_thread_members;
drop policy if exists "direct_thread_members_insert_group_by_creator" on public.direct_thread_members;

create policy "direct_thread_members_insert_dm_participant"
on public.direct_thread_members for insert
with check (
  coalesce(auth.role(), '') in ('authenticated', 'service_role')
  and
  exists (
    select 1
    from public.direct_threads t
    where t.id = direct_thread_members.thread_id
      and t.kind = 'dm'
      and auth.uid()::text in (split_part(direct_thread_members.thread_id, ':', 2), split_part(direct_thread_members.thread_id, ':', 3))
      and direct_thread_members.user_id::text in (split_part(direct_thread_members.thread_id, ':', 2), split_part(direct_thread_members.thread_id, ':', 3))
  )
);

create policy "direct_thread_members_insert_group_by_creator"
on public.direct_thread_members for insert
with check (
  exists (
    select 1
    from public.direct_threads t
    where t.id = direct_thread_members.thread_id
      and t.kind = 'group'
      and t.created_by = auth.uid()
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_messages_select_member" on public.direct_messages;
create policy "direct_messages_select_member"
on public.direct_messages for select
using (
  exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = direct_messages.thread_id
      and m.user_id = auth.uid()
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_messages_insert_member" on public.direct_messages;
create policy "direct_messages_insert_member"
on public.direct_messages for insert
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = direct_messages.thread_id
      and m.user_id = auth.uid()
  )
);

drop policy if exists "follows_select_public" on public.follows;
drop policy if exists "follows_select_own" on public.follows;
create policy "follows_select_public"
on public.follows for select
using (
  coalesce(auth.role(), '') in ('authenticated', 'service_role')
);

commit;
