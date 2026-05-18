-- =====================================================================
-- Smoke tests for relaxed role management (Princípio WhatsApp):
--   * Qualquer admin/mod/founder pode promover ou rebaixar outros
--   * O owner é IMUNE — não pode ser rebaixado nem removido por outros
--   * Só o owner pode transferir ownership
--
-- Migration sob teste: 20260518130000_relax_role_management.sql
-- Convention: SQL puro estilo prayer_reports_rpcs_smoke.sql.
-- =====================================================================

-- ---------- 1. BOOTSTRAP ROLES + AUTH SHIM ----------------------------

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end
$$;

create schema if not exists auth;
create table if not exists auth.users (id uuid primary key);

create or replace function auth.uid()
returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create or replace function auth.role()
returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to service_role;
-- Em Supabase prod authenticated/anon já têm os DML grants; aqui no
-- cluster temp precisamos conceder explicitamente. RLS faz o resto.
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on all tables in schema public to anon;

-- ---------- 2. CLEAN SLATE --------------------------------------------

truncate table public.community_members cascade;
truncate table public.communities cascade;
truncate table public.profiles cascade;
truncate table auth.users cascade;

-- ---------- 3. SEED ---------------------------------------------------

-- owner    = 11111111-... (criador da comunidade, imune)
-- admin_a  = 22222222-... (role='admin', pode gerenciar)
-- mod_a    = 33333333-... (role='moderator', pode gerenciar)
-- member_a = 44444444-... (role='member', NÃO pode gerenciar)
-- outsider = 55555555-... (não é membro)

insert into auth.users(id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222'),
  ('33333333-3333-3333-3333-333333333333'),
  ('44444444-4444-4444-4444-444444444444'),
  ('55555555-5555-5555-5555-555555555555');

insert into public.profiles(id, username, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'owner_user',   'Owner Tester'),
  ('22222222-2222-2222-2222-222222222222', 'admin_a',      'Admin A'),
  ('33333333-3333-3333-3333-333333333333', 'mod_a',        'Mod A'),
  ('44444444-4444-4444-4444-444444444444', 'member_a',     'Member A'),
  ('55555555-5555-5555-5555-555555555555', 'outsider',     'Outsider');

insert into public.communities(id, name, owner_id, is_closed, visibility) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Community',
   '11111111-1111-1111-1111-111111111111', true, 'private');

insert into public.community_members(community_id, user_id, role, status) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '11111111-1111-1111-1111-111111111111', 'admin', 'active'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '22222222-2222-2222-2222-222222222222', 'admin', 'active'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '33333333-3333-3333-3333-333333333333', 'moderator', 'active'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '44444444-4444-4444-4444-444444444444', 'member', 'active');

-- ---------- 4. SET ROLE/JWT FOR THE TESTS -----------------------------

reset role;
set role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', false);

-- =====================================================================
-- TEST 1: set_community_member_role — admin (não-owner) promove member
-- =====================================================================

-- 1.a Admin A promove Member A a 'admin' → ok
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
do $$
declare new_role text;
begin
  perform public.set_community_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '44444444-4444-4444-4444-444444444444',
    'admin'
  );
  select role into new_role
  from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '44444444-4444-4444-4444-444444444444';
  if new_role <> 'admin' then
    raise exception 'TEST 1.a: expected member role=admin, got %', new_role;
  end if;
end $$;

-- 1.b Admin A rebaixa Member A de volta a 'member' → ok
do $$
declare new_role text;
begin
  perform public.set_community_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '44444444-4444-4444-4444-444444444444',
    'member'
  );
  select role into new_role
  from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '44444444-4444-4444-4444-444444444444';
  if new_role <> 'member' then
    raise exception 'TEST 1.b: expected member role=member, got %', new_role;
  end if;
end $$;

-- 1.c Moderator pode promover também
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
do $$
begin
  perform public.set_community_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '44444444-4444-4444-4444-444444444444',
    'moderator'
  );
end $$;

-- restore member_a back to 'member' for downstream tests
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
do $$
begin
  perform public.set_community_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '44444444-4444-4444-4444-444444444444',
    'member'
  );
end $$;

-- =====================================================================
-- TEST 2: Owner é imune — não pode ser rebaixado por outros admins
-- =====================================================================

-- 2.a Admin A tenta rebaixar o Owner → owner_immutable
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
do $$
begin
  begin
    perform public.set_community_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '11111111-1111-1111-1111-111111111111',
      'member'
    );
    raise exception 'TEST 2.a: expected exception';
  exception when others then
    if sqlerrm <> 'owner_immutable' then
      raise exception 'TEST 2.a: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 2.b Owner tentando rebaixar a si mesmo também é bloqueado (owner_immutable)
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
do $$
begin
  begin
    perform public.set_community_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '11111111-1111-1111-1111-111111111111',
      'member'
    );
    raise exception 'TEST 2.b: expected exception';
  exception when others then
    if sqlerrm <> 'owner_immutable' then
      raise exception 'TEST 2.b: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- =====================================================================
-- TEST 3: Não-admin / outsider são bloqueados
-- =====================================================================

-- 3.a Member comum tenta promover outro → not_allowed
select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
do $$
begin
  begin
    perform public.set_community_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '33333333-3333-3333-3333-333333333333',
      'member'
    );
    raise exception 'TEST 3.a: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then
      raise exception 'TEST 3.a: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 3.b Outsider tenta → not_allowed
select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false);
do $$
begin
  begin
    perform public.set_community_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '44444444-4444-4444-4444-444444444444',
      'admin'
    );
    raise exception 'TEST 3.b: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then
      raise exception 'TEST 3.b: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 3.c Sem JWT → auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform public.set_community_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '44444444-4444-4444-4444-444444444444',
      'admin'
    );
    raise exception 'TEST 3.c: expected exception';
  exception when others then
    if sqlerrm <> 'auth_required' then
      raise exception 'TEST 3.c: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- =====================================================================
-- TEST 4: Erros de input continuam validados
-- =====================================================================

-- 4.a invalid_args (target null)
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
do $$
begin
  begin
    perform public.set_community_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      null,
      'admin'
    );
    raise exception 'TEST 4.a: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_args' then
      raise exception 'TEST 4.a: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 4.b invalid_role
do $$
begin
  begin
    perform public.set_community_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '44444444-4444-4444-4444-444444444444',
      'super_admin'
    );
    raise exception 'TEST 4.b: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_role' then
      raise exception 'TEST 4.b: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 4.c member_not_found
do $$
begin
  begin
    perform public.set_community_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '99999999-9999-9999-9999-999999999999',
      'admin'
    );
    raise exception 'TEST 4.c: expected exception';
  exception when others then
    if sqlerrm <> 'member_not_found' then
      raise exception 'TEST 4.c: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- =====================================================================
-- TEST 5: Delete policy — owner é imune ao kick de outros admins
--   Para testar a RLS policy precisamos exercitar o caminho de DELETE
--   sob a role 'authenticated' (security definer das RPCs faz bypass).
-- =====================================================================

-- 5.a Admin A consegue remover Member A (não-owner) → linha desaparece
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
do $$
declare n int;
begin
  delete from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '44444444-4444-4444-4444-444444444444';
  select count(*) into n from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '44444444-4444-4444-4444-444444444444';
  if n <> 0 then
    raise exception 'TEST 5.a: expected member_a removed, still % row(s)', n;
  end if;
end $$;

-- restore member_a para os testes seguintes (via service_role bypass)
reset role;
insert into public.community_members(community_id, user_id, role, status) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '44444444-4444-4444-4444-444444444444', 'member', 'active');
set role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', false);

-- 5.b Admin A NÃO consegue remover o Owner — a linha permanece intacta.
--    Sob RLS, o DELETE não falha; ele apenas não afeta linha alguma.
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
do $$
declare n int;
begin
  delete from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '11111111-1111-1111-1111-111111111111';
  select count(*) into n from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '11111111-1111-1111-1111-111111111111';
  if n <> 1 then
    raise exception 'TEST 5.b: owner row should be intact, got % row(s)', n;
  end if;
end $$;

-- 5.c Moderator também não consegue remover o Owner
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
do $$
declare n int;
begin
  delete from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '11111111-1111-1111-1111-111111111111';
  select count(*) into n from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '11111111-1111-1111-1111-111111111111';
  if n <> 1 then
    raise exception 'TEST 5.c: owner row should be intact, got % row(s)', n;
  end if;
end $$;

-- 5.d Member consegue sair sozinho (self-leave) — policy clause user_id = auth.uid()
select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
do $$
declare n int;
begin
  delete from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '44444444-4444-4444-4444-444444444444';
  select count(*) into n from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '44444444-4444-4444-4444-444444444444';
  if n <> 0 then
    raise exception 'TEST 5.d: member self-leave failed, % row(s) remain', n;
  end if;
end $$;

-- 5.e Owner consegue sair sozinho (self-leave do dono é permitido — ele decide).
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
do $$
declare n int;
begin
  delete from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '11111111-1111-1111-1111-111111111111';
  select count(*) into n from public.community_members
  where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    and user_id = '11111111-1111-1111-1111-111111111111';
  if n <> 0 then
    raise exception 'TEST 5.e: owner self-leave failed, % row(s) remain', n;
  end if;
end $$;

-- =====================================================================
-- DONE — if we got here without an exception, all assertions passed.
-- =====================================================================

reset role;
