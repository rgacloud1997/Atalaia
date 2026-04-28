begin;

alter table if exists public.direct_threads
  add column if not exists theme_key text;

alter table if exists public.direct_threads
  add column if not exists ephemeral_hours integer;

alter table if exists public.direct_thread_members
  add column if not exists nickname text;

update public.direct_threads
set theme_key = 'default'
where theme_key is null or btrim(theme_key) = '';

update public.direct_threads
set ephemeral_hours = 0
where ephemeral_hours is null;

alter table public.direct_threads
  alter column theme_key set default 'default';

alter table public.direct_threads
  alter column ephemeral_hours set default 0;

alter table public.direct_threads
  alter column theme_key set not null;

alter table public.direct_threads
  alter column ephemeral_hours set not null;

alter table public.direct_threads
  drop constraint if exists direct_threads_ephemeral_hours_check;

alter table public.direct_threads
  add constraint direct_threads_ephemeral_hours_check
  check (ephemeral_hours >= 0 and ephemeral_hours <= 168);

alter table public.direct_thread_members
  drop constraint if exists direct_thread_members_nickname_len_check;

alter table public.direct_thread_members
  add constraint direct_thread_members_nickname_len_check
  check (nickname is null or char_length(nickname) <= 64);

drop policy if exists "direct_threads_update_member" on public.direct_threads;
create policy "direct_threads_update_member"
on public.direct_threads for update
using (
  exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = direct_threads.id
      and m.user_id = auth.uid()
  )
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = direct_threads.id
      and m.user_id = auth.uid()
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_thread_members_select_member" on public.direct_thread_members;
create policy "direct_thread_members_select_member"
on public.direct_thread_members for select
using (
  exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = direct_thread_members.thread_id
      and m.user_id = auth.uid()
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_thread_members_update_member_nickname" on public.direct_thread_members;
create policy "direct_thread_members_update_member_nickname"
on public.direct_thread_members for update
using (
  exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = direct_thread_members.thread_id
      and m.user_id = auth.uid()
  )
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = direct_thread_members.thread_id
      and m.user_id = auth.uid()
  )
  or coalesce(auth.role(), '') = 'service_role'
);

create index if not exists idx_direct_threads_theme_key on public.direct_threads (theme_key);
create index if not exists idx_direct_threads_ephemeral_hours on public.direct_threads (ephemeral_hours);

grant select, insert, update on public.direct_threads to authenticated;
grant select, insert, update on public.direct_thread_members to authenticated;
grant select, insert on public.direct_messages to authenticated;

commit;
