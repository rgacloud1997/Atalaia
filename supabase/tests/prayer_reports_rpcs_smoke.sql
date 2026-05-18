-- =====================================================================
-- Smoke tests for the 8 Prayer-Reports RPCs delivered in Fase 2.2
-- (migrations 20260428110000…20260428113000)
--
-- Convention follows rls_smoke.sql:
--   * Plain SQL, no pg_tap
--   * Each assertion in a `do $$ ... $$` block that raises on failure
--   * Role + JWT claims set via `set role` + `select set_config(...)`
--
-- Coverage per RPC:
--   * happy path (admin, range that catches seeded data)
--   * auth_required        (empty JWT sub)
--   * community_required   (p_community_id => NULL)
--   * not_allowed          (non-admin caller)
--   * range_required       (p_from => NULL)            — where applicable
--   * invalid_range        (p_to < p_from)             — where applicable
--   * invalid_hour_range   (RPC 8 only)
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

create table if not exists auth.users (
  id uuid primary key
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create or replace function auth.role()
returns text
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to service_role;

-- ---------- 2. CLEAN SLATE --------------------------------------------

-- Order matters: children before parents to satisfy FK chains.
truncate table public.community_prayer_schedule_runs cascade;
truncate table public.community_prayer_schedules cascade;
truncate table public.prayer_targets cascade;
truncate table public.prayer_sessions cascade;
truncate table public.community_members cascade;
truncate table public.communities cascade;
truncate table public.profiles cascade;
truncate table public.locations cascade;
truncate table auth.users cascade;

-- ---------- 3. SEED ---------------------------------------------------

-- Fixed UUIDs so assertions can reference them directly.
-- admin     = aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa
-- member    = bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbbb
-- outsider  = ccccccc1-cccc-cccc-cccc-cccccccccccc (NOT a member of the community)
-- community = dddddddd-dddd-dddd-dddd-dddddddddddd
-- location  = eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee

insert into auth.users(id) values
  ('aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  ('ccccccc1-cccc-cccc-cccc-cccccccccccc');

insert into public.profiles(id, username, display_name) values
  ('aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin_user',  'Admin Tester'),
  ('bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'member_user', 'Member Tester'),
  ('ccccccc1-cccc-cccc-cccc-cccccccccccc', 'outsider',    'Outsider Tester');

insert into public.locations(id, level, name) values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'state', 'Brasília Test');

insert into public.communities(id, name, owner_id, is_closed, visibility) values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Test Community',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, 'private');

insert into public.community_members(community_id, user_id, role, status) values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin',  'active'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd',
   'bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'member', 'active');

insert into public.prayer_targets(id, community_id, title, target_type, created_by) values
  ('f1111111-1111-1111-1111-111111111111',
   'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Pela Nação',    'nation',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('f2222222-2222-2222-2222-222222222222',
   'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Pelas Famílias', 'group',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

insert into public.community_prayer_schedules(
  id, community_id, title, kind, prayer_target_id, created_by
) values
  ('54545454-1111-1111-1111-111111111111',
   'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Escala Nação', 'one_time',
   'f1111111-1111-1111-1111-111111111111',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('54545454-2222-2222-2222-222222222222',
   'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Escala Famílias', 'one_time',
   'f2222222-2222-2222-2222-222222222222',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Sessions for the completed runs (must come before runs because of FK on completed_session_id).
insert into public.prayer_sessions(
  id, user_id, location_id, location_level, community_id,
  started_at, ended_at, duration_seconds, status, notes
) values
  ('a1111111-1111-1111-1111-111111111111',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'state',
   'dddddddd-dddd-dddd-dddd-dddddddddddd',
   now() - interval '7 days', now() - interval '7 days' + interval '1 hour',
   3600, 'finished', 'orei pela nacao'),
  ('a2222222-2222-2222-2222-222222222222',
   'bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'state',
   'dddddddd-dddd-dddd-dddd-dddddddddddd',
   now() - interval '5 days', now() - interval '5 days' + interval '45 minutes',
   2700, 'finished', null);

-- Runs: 2 completed, 2 missed, 1 cancelled, 1 scheduled (future).
insert into public.community_prayer_schedule_runs(
  id, schedule_id, community_id, starts_at, ends_at,
  assigned_user_id, status, completed_session_id, created_by
) values
  ('11111111-1111-1111-1111-111111111111',
   '54545454-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
   now() - interval '7 days', now() - interval '7 days' + interval '1 hour',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'completed',
   'a1111111-1111-1111-1111-111111111111',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('22222222-2222-2222-2222-222222222222',
   '54545454-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
   now() - interval '5 days', now() - interval '5 days' + interval '1 hour',
   'bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'completed',
   'a2222222-2222-2222-2222-222222222222',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('33333333-3333-3333-3333-333333333333',
   '54545454-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
   now() - interval '3 days', now() - interval '3 days' + interval '1 hour',
   'bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'missed', null,
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('44444444-4444-4444-4444-444444444444',
   '54545454-2222-2222-2222-222222222222', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
   now() - interval '2 days', now() - interval '2 days' + interval '1 hour',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'missed', null,
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('55555555-5555-5555-5555-555555555555',
   '54545454-2222-2222-2222-222222222222', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
   now() - interval '1 day', now() - interval '1 day' + interval '1 hour',
   'bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cancelled', null,
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('66666666-6666-6666-6666-666666666666',
   '54545454-2222-2222-2222-222222222222', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
   now() + interval '1 day', now() + interval '1 day' + interval '1 hour',
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'scheduled', null,
   'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- ---------- 4. SET ROLE/JWT FOR THE TESTS -----------------------------

reset role;
set role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', false);

-- =====================================================================
-- TEST 1: get_prayer_scale_summary
-- =====================================================================

-- 1.a Happy path (admin) — should see runs in the last 14 days.
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
declare rec record;
begin
  select * into rec from public.get_prayer_scale_summary(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'utc')::date - 14,
    (now() at time zone 'utc')::date
  );
  if rec.total_runs is null or rec.total_runs < 5 then
    raise exception 'rpc1 happy: expected total_runs >= 5, got %', rec.total_runs;
  end if;
  if rec.total_completed <> 2 then
    raise exception 'rpc1 happy: expected total_completed=2, got %', rec.total_completed;
  end if;
  if rec.total_scales <> 2 then
    raise exception 'rpc1 happy: expected total_scales=2, got %', rec.total_scales;
  end if;
end $$;

-- 1.b auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform * from public.get_prayer_scale_summary(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc1 auth_required: expected exception, got success';
  exception when others then
    if sqlerrm <> 'auth_required' then
      raise exception 'rpc1 auth_required: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 1.c community_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_prayer_scale_summary(null, '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc1 community_required: expected exception';
  exception when others then
    if sqlerrm <> 'community_required' then
      raise exception 'rpc1 community_required: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 1.d not_allowed (outsider — not a community member)
select set_config('request.jwt.claim.sub', 'ccccccc1-cccc-cccc-cccc-cccccccccccc', false);
do $$
begin
  begin
    perform * from public.get_prayer_scale_summary(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc1 not_allowed: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then
      raise exception 'rpc1 not_allowed: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 1.e range_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_prayer_scale_summary(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', null::date, '2026-12-31'::date);
    raise exception 'rpc1 range_required: expected exception';
  exception when others then
    if sqlerrm <> 'range_required' then
      raise exception 'rpc1 range_required: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- 1.f invalid_range
do $$
begin
  begin
    perform * from public.get_prayer_scale_summary(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-12-31'::date, '2026-01-01'::date);
    raise exception 'rpc1 invalid_range: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_range' then
      raise exception 'rpc1 invalid_range: wrong message: %', sqlerrm;
    end if;
  end;
end $$;

-- =====================================================================
-- TEST 2: get_prayer_by_user_detailed
-- =====================================================================

-- 2.a Happy path
do $$
declare n int;
begin
  select count(*) into n from public.get_prayer_by_user_detailed(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'utc')::date - 14,
    (now() at time zone 'utc')::date
  );
  -- Both admin and member appear (each has runs in the window).
  if n < 2 then
    raise exception 'rpc2 happy: expected at least 2 user rows, got %', n;
  end if;
end $$;

-- 2.b auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform * from public.get_prayer_by_user_detailed(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc2 auth_required: expected exception';
  exception when others then
    if sqlerrm <> 'auth_required' then raise exception 'rpc2 auth_required: %', sqlerrm; end if;
  end;
end $$;

-- 2.c community_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_prayer_by_user_detailed(null, '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc2 community_required: expected exception';
  exception when others then
    if sqlerrm <> 'community_required' then raise exception 'rpc2 community_required: %', sqlerrm; end if;
  end;
end $$;

-- 2.d not_allowed
select set_config('request.jwt.claim.sub', 'ccccccc1-cccc-cccc-cccc-cccccccccccc', false);
do $$
begin
  begin
    perform * from public.get_prayer_by_user_detailed(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc2 not_allowed: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then raise exception 'rpc2 not_allowed: %', sqlerrm; end if;
  end;
end $$;

-- 2.e range_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_prayer_by_user_detailed(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', null::date, '2026-12-31'::date);
    raise exception 'rpc2 range_required: expected exception';
  exception when others then
    if sqlerrm <> 'range_required' then raise exception 'rpc2 range_required: %', sqlerrm; end if;
  end;
end $$;

-- 2.f invalid_range
do $$
begin
  begin
    perform * from public.get_prayer_by_user_detailed(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-12-31'::date, '2026-01-01'::date);
    raise exception 'rpc2 invalid_range: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_range' then raise exception 'rpc2 invalid_range: %', sqlerrm; end if;
  end;
end $$;

-- =====================================================================
-- TEST 3: get_prayers_by_completion_status
--   (no range_required / invalid_range checks in this RPC)
-- =====================================================================

-- 3.a Happy path
do $$
declare n int;
begin
  select count(*) into n from public.get_prayers_by_completion_status(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    now() - interval '14 days', now() + interval '14 days'
  );
  if n < 5 then
    raise exception 'rpc3 happy: expected >= 5 run rows, got %', n;
  end if;
end $$;

-- 3.b auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform * from public.get_prayers_by_completion_status(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', now() - interval '7 days', now());
    raise exception 'rpc3 auth_required: expected exception';
  exception when others then
    if sqlerrm <> 'auth_required' then raise exception 'rpc3 auth_required: %', sqlerrm; end if;
  end;
end $$;

-- 3.c community_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_prayers_by_completion_status(null, now() - interval '7 days', now());
    raise exception 'rpc3 community_required: expected exception';
  exception when others then
    if sqlerrm <> 'community_required' then raise exception 'rpc3 community_required: %', sqlerrm; end if;
  end;
end $$;

-- 3.d not_allowed
select set_config('request.jwt.claim.sub', 'ccccccc1-cccc-cccc-cccc-cccccccccccc', false);
do $$
begin
  begin
    perform * from public.get_prayers_by_completion_status(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', now() - interval '7 days', now());
    raise exception 'rpc3 not_allowed: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then raise exception 'rpc3 not_allowed: %', sqlerrm; end if;
  end;
end $$;

-- =====================================================================
-- TEST 4: get_coverage_by_region
-- =====================================================================

select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);

-- 4.a Happy path — region is derived from prayer_sessions.location_id OR user primary region.
do $$
declare n int;
begin
  select count(*) into n from public.get_coverage_by_region(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'utc')::date - 14,
    (now() at time zone 'utc')::date
  );
  -- At least the one seeded region appears (admin + member have sessions there).
  if n < 1 then
    raise exception 'rpc4 happy: expected >= 1 region row, got %', n;
  end if;
end $$;

-- 4.b auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform * from public.get_coverage_by_region(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc4 auth_required: expected exception';
  exception when others then
    if sqlerrm <> 'auth_required' then raise exception 'rpc4 auth_required: %', sqlerrm; end if;
  end;
end $$;

-- 4.c community_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_coverage_by_region(null, '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc4 community_required: expected exception';
  exception when others then
    if sqlerrm <> 'community_required' then raise exception 'rpc4 community_required: %', sqlerrm; end if;
  end;
end $$;

-- 4.d not_allowed
select set_config('request.jwt.claim.sub', 'ccccccc1-cccc-cccc-cccc-cccccccccccc', false);
do $$
begin
  begin
    perform * from public.get_coverage_by_region(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc4 not_allowed: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then raise exception 'rpc4 not_allowed: %', sqlerrm; end if;
  end;
end $$;

-- 4.e range_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_coverage_by_region(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', null::date, '2026-12-31'::date);
    raise exception 'rpc4 range_required: expected exception';
  exception when others then
    if sqlerrm <> 'range_required' then raise exception 'rpc4 range_required: %', sqlerrm; end if;
  end;
end $$;

-- 4.f invalid_range
do $$
begin
  begin
    perform * from public.get_coverage_by_region(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-12-31'::date, '2026-01-01'::date);
    raise exception 'rpc4 invalid_range: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_range' then raise exception 'rpc4 invalid_range: %', sqlerrm; end if;
  end;
end $$;

-- =====================================================================
-- TEST 5: get_coverage_by_target
-- =====================================================================

-- 5.a Happy path — both seeded targets should appear (each has runs).
do $$
declare n int;
begin
  select count(*) into n from public.get_coverage_by_target(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'utc')::date - 14,
    (now() at time zone 'utc')::date
  );
  if n < 2 then
    raise exception 'rpc5 happy: expected >= 2 target rows, got %', n;
  end if;
end $$;

-- 5.b auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform * from public.get_coverage_by_target(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc5 auth_required: expected exception';
  exception when others then
    if sqlerrm <> 'auth_required' then raise exception 'rpc5 auth_required: %', sqlerrm; end if;
  end;
end $$;

-- 5.c community_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_coverage_by_target(null, '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc5 community_required: expected exception';
  exception when others then
    if sqlerrm <> 'community_required' then raise exception 'rpc5 community_required: %', sqlerrm; end if;
  end;
end $$;

-- 5.d not_allowed
select set_config('request.jwt.claim.sub', 'ccccccc1-cccc-cccc-cccc-cccccccccccc', false);
do $$
begin
  begin
    perform * from public.get_coverage_by_target(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc5 not_allowed: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then raise exception 'rpc5 not_allowed: %', sqlerrm; end if;
  end;
end $$;

-- 5.e range_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_coverage_by_target(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', null::date, '2026-12-31'::date);
    raise exception 'rpc5 range_required: expected exception';
  exception when others then
    if sqlerrm <> 'range_required' then raise exception 'rpc5 range_required: %', sqlerrm; end if;
  end;
end $$;

-- 5.f invalid_range
do $$
begin
  begin
    perform * from public.get_coverage_by_target(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-12-31'::date, '2026-01-01'::date);
    raise exception 'rpc5 invalid_range: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_range' then raise exception 'rpc5 invalid_range: %', sqlerrm; end if;
  end;
end $$;

-- =====================================================================
-- TEST 6: get_time_slot_coverage
-- =====================================================================

-- 6.a Happy path — should return exactly 24 hourly slots for the default p_slot_minutes=60.
do $$
declare n int;
begin
  select count(*) into n from public.get_time_slot_coverage(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'utc')::date - 14,
    (now() at time zone 'utc')::date
  );
  if n <> 24 then
    raise exception 'rpc6 happy: expected 24 hourly slots, got %', n;
  end if;
end $$;

-- 6.b auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform * from public.get_time_slot_coverage(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc6 auth_required: expected exception';
  exception when others then
    if sqlerrm <> 'auth_required' then raise exception 'rpc6 auth_required: %', sqlerrm; end if;
  end;
end $$;

-- 6.c community_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_time_slot_coverage(null, '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc6 community_required: expected exception';
  exception when others then
    if sqlerrm <> 'community_required' then raise exception 'rpc6 community_required: %', sqlerrm; end if;
  end;
end $$;

-- 6.d not_allowed
select set_config('request.jwt.claim.sub', 'ccccccc1-cccc-cccc-cccc-cccccccccccc', false);
do $$
begin
  begin
    perform * from public.get_time_slot_coverage(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc6 not_allowed: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then raise exception 'rpc6 not_allowed: %', sqlerrm; end if;
  end;
end $$;

-- 6.e range_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_time_slot_coverage(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', null::date, '2026-12-31'::date);
    raise exception 'rpc6 range_required: expected exception';
  exception when others then
    if sqlerrm <> 'range_required' then raise exception 'rpc6 range_required: %', sqlerrm; end if;
  end;
end $$;

-- 6.f invalid_range
do $$
begin
  begin
    perform * from public.get_time_slot_coverage(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-12-31'::date, '2026-01-01'::date);
    raise exception 'rpc6 invalid_range: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_range' then raise exception 'rpc6 invalid_range: %', sqlerrm; end if;
  end;
end $$;

-- =====================================================================
-- TEST 7: get_failure_analysis
-- =====================================================================

-- 7.a Happy path — both admin (1 missed) and member (1 missed) should appear.
do $$
declare n int;
begin
  select count(*) into n from public.get_failure_analysis(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'utc')::date - 14,
    (now() at time zone 'utc')::date
  );
  if n < 2 then
    raise exception 'rpc7 happy: expected >= 2 failure rows (admin + member each missed once), got %', n;
  end if;
end $$;

-- 7.b auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform * from public.get_failure_analysis(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc7 auth_required: expected exception';
  exception when others then
    if sqlerrm <> 'auth_required' then raise exception 'rpc7 auth_required: %', sqlerrm; end if;
  end;
end $$;

-- 7.c community_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_failure_analysis(null, '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc7 community_required: expected exception';
  exception when others then
    if sqlerrm <> 'community_required' then raise exception 'rpc7 community_required: %', sqlerrm; end if;
  end;
end $$;

-- 7.d not_allowed
select set_config('request.jwt.claim.sub', 'ccccccc1-cccc-cccc-cccc-cccccccccccc', false);
do $$
begin
  begin
    perform * from public.get_failure_analysis(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-01-01'::date, '2026-12-31'::date);
    raise exception 'rpc7 not_allowed: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then raise exception 'rpc7 not_allowed: %', sqlerrm; end if;
  end;
end $$;

-- 7.e range_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_failure_analysis(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', null::date, '2026-12-31'::date);
    raise exception 'rpc7 range_required: expected exception';
  exception when others then
    if sqlerrm <> 'range_required' then raise exception 'rpc7 range_required: %', sqlerrm; end if;
  end;
end $$;

-- 7.f invalid_range
do $$
begin
  begin
    perform * from public.get_failure_analysis(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', '2026-12-31'::date, '2026-01-01'::date);
    raise exception 'rpc7 invalid_range: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_range' then raise exception 'rpc7 invalid_range: %', sqlerrm; end if;
  end;
end $$;

-- =====================================================================
-- TEST 8: get_prayer_report_cross_data (generic filter RPC)
-- =====================================================================

-- 8.a Happy path — no filters, last 14 days.
do $$
declare n int;
begin
  select count(*) into n from public.get_prayer_report_cross_data(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    now() - interval '14 days', now() + interval '14 days'
  );
  if n < 5 then
    raise exception 'rpc8 happy: expected >= 5 run rows, got %', n;
  end if;
end $$;

-- 8.b Filter sanity — restrict to status=missed: must return exactly the 2 missed runs.
do $$
declare n int;
begin
  select count(*) into n from public.get_prayer_report_cross_data(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    now() - interval '14 days', now() + interval '14 days',
    null, null, null,
    array['missed']::text[]
  );
  if n <> 2 then
    raise exception 'rpc8 filter: expected exactly 2 missed runs, got %', n;
  end if;
end $$;

-- 8.c auth_required
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform * from public.get_prayer_report_cross_data(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', now() - interval '7 days', now());
    raise exception 'rpc8 auth_required: expected exception';
  exception when others then
    if sqlerrm <> 'auth_required' then raise exception 'rpc8 auth_required: %', sqlerrm; end if;
  end;
end $$;

-- 8.d community_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_prayer_report_cross_data(null, now() - interval '7 days', now());
    raise exception 'rpc8 community_required: expected exception';
  exception when others then
    if sqlerrm <> 'community_required' then raise exception 'rpc8 community_required: %', sqlerrm; end if;
  end;
end $$;

-- 8.e not_allowed
select set_config('request.jwt.claim.sub', 'ccccccc1-cccc-cccc-cccc-cccccccccccc', false);
do $$
begin
  begin
    perform * from public.get_prayer_report_cross_data(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', now() - interval '7 days', now());
    raise exception 'rpc8 not_allowed: expected exception';
  exception when others then
    if sqlerrm <> 'not_allowed' then raise exception 'rpc8 not_allowed: %', sqlerrm; end if;
  end;
end $$;

-- 8.f range_required
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
  begin
    perform * from public.get_prayer_report_cross_data(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', null::timestamptz, now());
    raise exception 'rpc8 range_required: expected exception';
  exception when others then
    if sqlerrm <> 'range_required' then raise exception 'rpc8 range_required: %', sqlerrm; end if;
  end;
end $$;

-- 8.g invalid_range
do $$
begin
  begin
    perform * from public.get_prayer_report_cross_data(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', now() + interval '1 day', now() - interval '7 days');
    raise exception 'rpc8 invalid_range: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_range' then raise exception 'rpc8 invalid_range: %', sqlerrm; end if;
  end;
end $$;

-- 8.h invalid_hour_range (p_hour_end < p_hour_start)
do $$
begin
  begin
    perform * from public.get_prayer_report_cross_data(
      'dddddddd-dddd-dddd-dddd-dddddddddddd',
      now() - interval '7 days', now(),
      null, null, null, null, null,
      22, 6   -- end < start
    );
    raise exception 'rpc8 invalid_hour_range: expected exception';
  exception when others then
    if sqlerrm <> 'invalid_hour_range' then raise exception 'rpc8 invalid_hour_range: %', sqlerrm; end if;
  end;
end $$;

-- =====================================================================
-- TEST 9: p_tz parameter (migration 20260518110000_reports_rpcs_p_tz.sql)
-- =====================================================================

-- 9.a get_prayer_scale_summary accepts p_tz and still returns 1 summary row.
select set_config('request.jwt.claim.sub', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
declare n int;
begin
  select count(*) into n from public.get_prayer_scale_summary(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'America/Sao_Paulo')::date - 14,
    (now() at time zone 'America/Sao_Paulo')::date,
    'America/Sao_Paulo'
  );
  if n <> 1 then
    raise exception 'rpc1 p_tz: expected exactly 1 summary row, got %', n;
  end if;
end $$;

-- 9.b get_prayer_by_user_detailed accepts p_tz.
do $$
declare n int;
begin
  select count(*) into n from public.get_prayer_by_user_detailed(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'America/Sao_Paulo')::date - 14,
    (now() at time zone 'America/Sao_Paulo')::date,
    'America/Sao_Paulo'
  );
  if n < 2 then
    raise exception 'rpc2 p_tz: expected >= 2 user rows, got %', n;
  end if;
end $$;

-- 9.c get_coverage_by_region accepts p_tz.
do $$
declare n int;
begin
  select count(*) into n from public.get_coverage_by_region(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'America/Sao_Paulo')::date - 14,
    (now() at time zone 'America/Sao_Paulo')::date,
    'America/Sao_Paulo'
  );
  if n < 1 then
    raise exception 'rpc4 p_tz: expected >= 1 region row, got %', n;
  end if;
end $$;

-- 9.d get_coverage_by_target accepts p_tz.
do $$
declare n int;
begin
  select count(*) into n from public.get_coverage_by_target(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'America/Sao_Paulo')::date - 14,
    (now() at time zone 'America/Sao_Paulo')::date,
    'America/Sao_Paulo'
  );
  if n < 2 then
    raise exception 'rpc5 p_tz: expected >= 2 target rows, got %', n;
  end if;
end $$;

-- 9.e get_time_slot_coverage accepts p_tz — still 24 hourly slots, but
-- the runs may now land in different hour buckets (shift of 3h vs UTC).
do $$
declare n int;
begin
  select count(*) into n from public.get_time_slot_coverage(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'America/Sao_Paulo')::date - 14,
    (now() at time zone 'America/Sao_Paulo')::date,
    60,
    'America/Sao_Paulo'
  );
  if n <> 24 then
    raise exception 'rpc6 p_tz: expected 24 slots, got %', n;
  end if;
end $$;

-- 9.f get_failure_analysis accepts p_tz.
do $$
declare n int;
begin
  select count(*) into n from public.get_failure_analysis(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    (now() at time zone 'America/Sao_Paulo')::date - 14,
    (now() at time zone 'America/Sao_Paulo')::date,
    'America/Sao_Paulo'
  );
  if n < 2 then
    raise exception 'rpc7 p_tz: expected >= 2 failure rows, got %', n;
  end if;
end $$;

-- 9.g get_prayer_report_cross_data accepts p_tz (note: p_tz is the LAST
-- positional arg, so we pass all the optionals explicitly).
do $$
declare n int;
begin
  select count(*) into n from public.get_prayer_report_cross_data(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    now() - interval '14 days', now() + interval '14 days',
    null, null, null, null, null,
    0, 23, 200, 0,
    'America/Sao_Paulo'
  );
  if n < 5 then
    raise exception 'rpc8 p_tz: expected >= 5 rows, got %', n;
  end if;
end $$;

-- =====================================================================
-- DONE — if we got here without an exception, all assertions passed.
-- =====================================================================

reset role;
