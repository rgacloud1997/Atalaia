begin;

-- Avoid RLS policy recursion by using a SECURITY DEFINER helper with row_security disabled.
create or replace function public.is_direct_thread_member(p_thread_id text, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.direct_thread_members m
    where m.thread_id = p_thread_id
      and m.user_id = p_user_id
  );
$$;

revoke all on function public.is_direct_thread_member(text, uuid) from public;
grant execute on function public.is_direct_thread_member(text, uuid) to authenticated;
grant execute on function public.is_direct_thread_member(text, uuid) to service_role;

drop policy if exists "direct_thread_members_select_member" on public.direct_thread_members;
create policy "direct_thread_members_select_member"
on public.direct_thread_members for select
using (
  public.is_direct_thread_member(direct_thread_members.thread_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_thread_members_update_member_nickname" on public.direct_thread_members;
create policy "direct_thread_members_update_member_nickname"
on public.direct_thread_members for update
using (
  (
    direct_thread_members.user_id = auth.uid()
    and public.is_direct_thread_member(direct_thread_members.thread_id, auth.uid())
  )
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  (
    direct_thread_members.user_id = auth.uid()
    and public.is_direct_thread_member(direct_thread_members.thread_id, auth.uid())
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_threads_update_member" on public.direct_threads;
create policy "direct_threads_update_member"
on public.direct_threads for update
using (
  public.is_direct_thread_member(direct_threads.id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  public.is_direct_thread_member(direct_threads.id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

commit;
