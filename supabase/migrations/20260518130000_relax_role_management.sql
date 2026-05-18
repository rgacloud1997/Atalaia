-- Decisão de produto (18/05/2026): qualquer admin/moderator/founder de
-- uma comunidade pode promover ou rebaixar outros membros. MAS o owner
-- (quem criou o grupo) é imune — não pode ser rebaixado nem removido
-- por outros admins. Princípio "dono de grupo WhatsApp": só perde o
-- papel se transferir ownership explicitamente.
--
-- 1) `set_community_member_role` passa a aceitar qualquer admin como
--    caller (community_is_admin) em vez de exigir owner. Adiciona
--    salvaguarda nova: o target NÃO pode ser o owner da comunidade
--    (erro `owner_immutable`).
--
-- 2) Policy `community_members_delete_own_or_admin` é substituída por
--    uma versão que continua liberando self-leave (user_id = auth.uid())
--    mas bloqueia admins de remover a row do owner. Self-leave do owner
--    continua possível — quem decide sair é o próprio dono.
--
-- 3) `transfer_community_ownership` permanece owner-only (decisão de
--    transferência continua sendo prerrogativa exclusiva do dono).

begin;

create or replace function public.set_community_member_role(
  p_community_id uuid,
  p_target_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(nullif(trim(lower(p_role)), ''), '');
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;
  if p_community_id is null or p_target_user_id is null then
    raise exception 'invalid_args';
  end if;
  if not public.community_is_admin(p_community_id, v_uid) then
    raise exception 'not_allowed';
  end if;
  if exists (
    select 1
    from public.communities c
    where c.id = p_community_id
      and c.owner_id = p_target_user_id
  ) then
    raise exception 'owner_immutable';
  end if;
  if v_role not in ('member', 'moderator', 'admin') then
    raise exception 'invalid_role';
  end if;

  update public.community_members
  set role = v_role
  where community_id = p_community_id
    and user_id = p_target_user_id
    and status = 'active';

  if not found then
    raise exception 'member_not_found';
  end if;
end;
$$;

-- Refresh grants (assinatura inalterada, recreate por segurança).
revoke all on function public.set_community_member_role(uuid, uuid, text) from public;
grant execute on function public.set_community_member_role(uuid, uuid, text) to authenticated;

-- Replace delete policy so admins cannot remove the owner.
drop policy if exists "community_members_delete_own_or_admin" on public.community_members;
create policy "community_members_delete_own_or_admin"
on public.community_members for delete
using (
  user_id = auth.uid()
  or (
    public.community_is_admin(community_id, auth.uid())
    and not exists (
      select 1
      from public.communities c
      where c.id = community_members.community_id
        and c.owner_id = community_members.user_id
    )
  )
);

commit;
