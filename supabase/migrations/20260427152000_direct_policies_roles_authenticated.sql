begin;

-- Keep the same logic, but restrict policies to authenticated/service_role.

drop policy if exists "direct_thread_members_select_member" on public.direct_thread_members;
create policy "direct_thread_members_select_member"
on public.direct_thread_members for select
to authenticated, service_role
using (
  public.is_direct_thread_member(direct_thread_members.thread_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "direct_thread_members_update_member_nickname" on public.direct_thread_members;
create policy "direct_thread_members_update_member_nickname"
on public.direct_thread_members for update
to authenticated, service_role
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
to authenticated, service_role
using (
  public.is_direct_thread_member(direct_threads.id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  public.is_direct_thread_member(direct_threads.id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

commit;

