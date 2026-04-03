do $$
begin
  if not exists(select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists(select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists(select 1 from pg_roles where rolname = 'service_role') then
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

grant select on public.posts, public.profiles, public.follows, public.locations, public.location_aggregates, public.communities, public.community_members to anon, authenticated;
grant select on public.comments, public.reactions, public.prayers, public.post_media to authenticated;
grant insert, update, delete on public.posts, public.follows, public.comments, public.reactions, public.prayers, public.post_media, public.communities, public.community_members to authenticated;
grant select, insert, update, delete on public.notifications, public.reports to authenticated;
grant select, insert, update, delete on all tables in schema public to service_role;

truncate table public.community_members cascade;
truncate table public.communities cascade;
truncate table public.prayers cascade;
truncate table public.reactions cascade;
truncate table public.comments cascade;
truncate table public.post_media cascade;
truncate table public.posts cascade;
truncate table public.follows cascade;
truncate table public.profiles cascade;
truncate table auth.users cascade;

insert into auth.users(id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222'),
  ('33333333-3333-3333-3333-333333333333');

insert into public.profiles(id, username, church_id) values
  ('11111111-1111-1111-1111-111111111111', 'u1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('22222222-2222-2222-2222-222222222222', 'u2', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('33333333-3333-3333-3333-333333333333', 'u3', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

insert into public.follows(follower_id, following_id) values
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

insert into public.communities(id, name, owner_id, is_closed) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Comm', '22222222-2222-2222-2222-222222222222', true);

insert into public.community_members(community_id, user_id, status) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'active');

insert into public.posts(id, user_id, kind, visibility, church_id, community_id, body) values
  ('00000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'request', 'public', null, null, 'public-u2'),
  ('00000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'request', 'followers', null, null, 'followers-u2'),
  ('00000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'request', 'church', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', null, 'churchA-u2'),
  ('00000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'request', 'church', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', null, 'churchB-u2'),
  ('00000000-0000-0000-0000-000000000005', '22222222-2222-2222-2222-222222222222', 'request', 'public', null, 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'comm-public-u2'),
  ('00000000-0000-0000-0000-000000000006', '33333333-3333-3333-3333-333333333333', 'request', 'public', null, null, 'public-u3');

reset role;
set role anon;
select set_config('request.jwt.claim.role', 'anon', false);
select set_config('request.jwt.claim.sub', '', false);

do $$
declare
  n int;
begin
  select count(*) into n from public.posts;
  if n <> 2 then
    raise exception 'anon expected 2 posts, got %', n;
  end if;
end
$$;

reset role;
set role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', false);
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

do $$
declare
  n int;
begin
  select count(*) into n from public.posts;
  if n <> 5 then
    raise exception 'u1 expected 5 posts, got %', n;
  end if;
end
$$;

do $$
begin
  begin
    insert into public.comments(post_id, user_id, body)
    values ('00000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'x');
    raise exception 'expected RLS failure for comment on invisible post';
  exception when insufficient_privilege then
    null;
  end;
end
$$;

insert into public.comments(post_id, user_id, body)
values ('00000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'ok');

do $$
declare
  c int;
begin
  select comment_count into c from public.posts where id = '00000000-0000-0000-0000-000000000001';
  if c <> 1 then
    raise exception 'expected comment_count=1, got %', c;
  end if;
end
$$;

reset role;
set role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', false);
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);

do $$
declare
  n int;
begin
  select count(*) into n from public.posts;
  if n <> 3 then
    raise exception 'u3 expected 3 posts, got %', n;
  end if;
end
$$;
