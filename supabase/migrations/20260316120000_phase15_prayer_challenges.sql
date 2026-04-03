begin;

create table if not exists public.prayer_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete restrict,
  location_level public.location_level not null,
  challenge_id uuid null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds integer not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

alter table public.prayer_sessions
  drop constraint if exists prayer_sessions_status_check;

alter table public.prayer_sessions
  add constraint prayer_sessions_status_check
  check (status in ('active', 'finished', 'cancelled')) not valid;

create index if not exists idx_prayer_sessions_user_id_created_at on public.prayer_sessions (user_id, created_at desc);
create index if not exists idx_prayer_sessions_challenge_id on public.prayer_sessions (challenge_id, created_at desc);
create index if not exists idx_prayer_sessions_location_id on public.prayer_sessions (location_id, created_at desc);

alter table public.prayer_sessions enable row level security;

drop policy if exists "prayer_sessions_select_own" on public.prayer_sessions;
create policy "prayer_sessions_select_own"
on public.prayer_sessions for select
using (auth.uid() = user_id);

drop policy if exists "prayer_sessions_insert_own" on public.prayer_sessions;
create policy "prayer_sessions_insert_own"
on public.prayer_sessions for insert
with check (auth.uid() = user_id);

drop policy if exists "prayer_sessions_update_own" on public.prayer_sessions;
create policy "prayer_sessions_update_own"
on public.prayer_sessions for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select, insert, update on public.prayer_sessions to authenticated;

create table if not exists public.prayer_challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  image_url text,
  target_region text not null,
  target_location_id uuid references public.locations(id) on delete set null,
  community_id uuid references public.communities(id) on delete set null,
  start_date timestamptz not null,
  end_date timestamptz not null,
  goal_participants integer not null default 0,
  goal_prayer_minutes integer not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

alter table public.prayer_sessions
  drop constraint if exists prayer_sessions_challenge_id_fkey;

alter table public.prayer_sessions
  add constraint prayer_sessions_challenge_id_fkey
  foreign key (challenge_id) references public.prayer_challenges(id) on delete set null;

alter table public.prayer_challenges
  drop constraint if exists prayer_challenges_status_check;

alter table public.prayer_challenges
  add constraint prayer_challenges_status_check
  check (status in ('draft', 'active', 'ended', 'archived')) not valid;

alter table public.prayer_challenges
  drop constraint if exists prayer_challenges_date_check;

alter table public.prayer_challenges
  add constraint prayer_challenges_date_check
  check (end_date >= start_date) not valid;

create index if not exists idx_prayer_challenges_status_dates on public.prayer_challenges (status, start_date, end_date);
create index if not exists idx_prayer_challenges_community_id on public.prayer_challenges (community_id);
create index if not exists idx_prayer_challenges_target_location_id on public.prayer_challenges (target_location_id);

create or replace function public.sync_prayer_challenge_target_location()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.target_location_id is null and new.target_region is not null and new.target_region <> '' then
    select l.id
    into new.target_location_id
    from public.locations l
    where l.path = new.target_region
    limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prayer_challenges_target_location on public.prayer_challenges;
create trigger trg_prayer_challenges_target_location
before insert or update on public.prayer_challenges
for each row execute function public.sync_prayer_challenge_target_location();

alter table public.prayer_challenges enable row level security;

drop policy if exists "prayer_challenges_select_visible" on public.prayer_challenges;
create policy "prayer_challenges_select_visible"
on public.prayer_challenges for select
using (
  (
    auth.uid() is not null
    and (
      community_id is null
      or public.community_can_view(community_id, auth.uid())
    )
  )
  or (
    auth.uid() is null
    and community_id is null
    and status = 'active'
    and start_date <= now()
    and end_date >= now()
  )
);

drop policy if exists "prayer_challenges_insert_admin" on public.prayer_challenges;
create policy "prayer_challenges_insert_admin"
on public.prayer_challenges for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or (auth.uid() is not null and community_id is not null and public.community_is_admin(community_id, auth.uid()))
);

drop policy if exists "prayer_challenges_update_admin" on public.prayer_challenges;
create policy "prayer_challenges_update_admin"
on public.prayer_challenges for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or (auth.uid() is not null and community_id is not null and public.community_is_admin(community_id, auth.uid()))
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or (auth.uid() is not null and community_id is not null and public.community_is_admin(community_id, auth.uid()))
);

grant select, insert, update on public.prayer_challenges to authenticated;
grant select on public.prayer_challenges to anon;

create table if not exists public.challenge_participants (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.prayer_challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now()
);

create unique index if not exists idx_challenge_participants_unique on public.challenge_participants (challenge_id, user_id);
create index if not exists idx_challenge_participants_challenge_id on public.challenge_participants (challenge_id, joined_at desc);
create index if not exists idx_challenge_participants_user_id on public.challenge_participants (user_id, joined_at desc);

alter table public.challenge_participants enable row level security;

drop policy if exists "challenge_participants_select_visible" on public.challenge_participants;
create policy "challenge_participants_select_visible"
on public.challenge_participants for select
using (
  exists (
    select 1
    from public.prayer_challenges c
    where c.id = challenge_participants.challenge_id
      and (
        c.community_id is null
        or (auth.uid() is not null and public.community_can_view(c.community_id, auth.uid()))
      )
  )
);

drop policy if exists "challenge_participants_insert_own" on public.challenge_participants;
create policy "challenge_participants_insert_own"
on public.challenge_participants for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.prayer_challenges c
    where c.id = challenge_id
      and c.status = 'active'
      and c.start_date <= now()
      and c.end_date >= now()
      and (
        c.community_id is null
        or public.community_can_view(c.community_id, auth.uid())
      )
  )
);

drop policy if exists "challenge_participants_delete_own" on public.challenge_participants;
create policy "challenge_participants_delete_own"
on public.challenge_participants for delete
using (auth.uid() = user_id);

grant select, insert, delete on public.challenge_participants to authenticated;
grant select on public.challenge_participants to anon;

create table if not exists public.user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_type text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_user_badges_unique on public.user_badges (user_id, badge_type);
create index if not exists idx_user_badges_user_id_created_at on public.user_badges (user_id, created_at desc);

alter table public.user_badges enable row level security;

drop policy if exists "user_badges_select_public" on public.user_badges;
create policy "user_badges_select_public"
on public.user_badges for select
using (true);

drop policy if exists "user_badges_insert_service_role" on public.user_badges;
create policy "user_badges_insert_service_role"
on public.user_badges for insert
with check (coalesce(auth.role(), '') = 'service_role');

grant select on public.user_badges to anon, authenticated;
grant insert on public.user_badges to service_role;

create or replace function public.award_badge(p_user_id uuid, p_badge_type text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null or p_badge_type is null or p_badge_type = '' then
    return;
  end if;
  insert into public.user_badges (user_id, badge_type)
  values (p_user_id, p_badge_type)
  on conflict (user_id, badge_type) do nothing;
end;
$$;

create or replace function public.join_prayer_challenge(p_challenge_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_inserted boolean := false;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  insert into public.challenge_participants (challenge_id, user_id)
  select p_challenge_id, v_uid
  where exists (
    select 1
    from public.prayer_challenges c
    where c.id = p_challenge_id
      and c.status = 'active'
      and c.start_date <= now()
      and c.end_date >= now()
      and (
        c.community_id is null
        or public.community_can_view(c.community_id, v_uid)
      )
  )
  on conflict (challenge_id, user_id) do nothing;

  v_inserted := found;

  perform public.award_badge(v_uid, 'intercessor_global');
  return v_inserted;
end;
$$;

create or replace function public.leave_prayer_challenge(p_challenge_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_deleted boolean := false;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  delete from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_uid;
  v_deleted := found;
  return v_deleted;
end;
$$;

create or replace function public.list_prayer_challenges(
  p_only_active boolean default true,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  title text,
  description text,
  image_url text,
  target_region text,
  target_location_id uuid,
  target_location_name text,
  community_id uuid,
  community_name text,
  start_date timestamptz,
  end_date timestamptz,
  goal_participants integer,
  goal_prayer_minutes integer,
  status text,
  created_at timestamptz,
  participants_count bigint,
  viewer_joined boolean,
  total_duration_seconds bigint
)
language sql
stable
set search_path = public
as $$
  with base as (
    select c.*
    from public.prayer_challenges c
    where (
        auth.uid() is not null
        and (c.community_id is null or public.community_can_view(c.community_id, auth.uid()))
      )
      or (
        auth.uid() is null
        and c.community_id is null
        and c.status = 'active'
        and c.start_date <= now()
        and c.end_date >= now()
      )
  )
  select
    c.id,
    c.title,
    c.description,
    c.image_url,
    c.target_region,
    c.target_location_id,
    l.name as target_location_name,
    c.community_id,
    comm.name as community_name,
    c.start_date,
    c.end_date,
    c.goal_participants,
    c.goal_prayer_minutes,
    c.status,
    c.created_at,
    (select count(*) from public.challenge_participants cp where cp.challenge_id = c.id) as participants_count,
    exists (
      select 1
      from public.challenge_participants cp
      where cp.challenge_id = c.id
        and cp.user_id = auth.uid()
    ) as viewer_joined,
    coalesce(
      (
        select sum(ps.duration_seconds)
        from public.prayer_sessions ps
        where ps.challenge_id = c.id
          and ps.status = 'finished'
      ),
      0
    ) as total_duration_seconds
  from base c
  left join public.locations l on l.id = c.target_location_id
  left join public.communities comm on comm.id = c.community_id
  where (
    p_only_active is false
    or (
      c.status = 'active'
      and c.start_date <= now()
      and c.end_date >= now()
    )
  )
  order by c.start_date desc, c.created_at desc
  limit greatest(p_limit, 1)
  offset greatest(p_offset, 0);
$$;

create or replace function public.prayer_challenge_progress(p_challenge_id uuid)
returns table (
  challenge_id uuid,
  participants_count bigint,
  goal_participants integer,
  total_duration_seconds bigint,
  goal_prayer_minutes integer
)
language sql
stable
set search_path = public
as $$
  select
    c.id as challenge_id,
    (select count(*) from public.challenge_participants cp where cp.challenge_id = c.id) as participants_count,
    c.goal_participants,
    coalesce(
      (
        select sum(ps.duration_seconds)
        from public.prayer_sessions ps
        where ps.challenge_id = c.id
          and ps.status = 'finished'
      ),
      0
    ) as total_duration_seconds,
    c.goal_prayer_minutes
  from public.prayer_challenges c
  where c.id = p_challenge_id
    and (
      (auth.uid() is not null and (c.community_id is null or public.community_can_view(c.community_id, auth.uid())))
      or (auth.uid() is null and c.community_id is null and c.status = 'active' and c.start_date <= now() and c.end_date >= now())
    )
  limit 1;
$$;

create or replace function public.prayer_challenges_for_map(
  p_community_id uuid default null,
  p_limit integer default 60
)
returns table (
  id uuid,
  title text,
  community_id uuid,
  community_name text,
  target_region text,
  target_location_id uuid,
  target_location_name text,
  center_lat double precision,
  center_lng double precision,
  start_date timestamptz,
  end_date timestamptz,
  goal_participants integer,
  participants_count bigint
)
language sql
stable
set search_path = public
as $$
  select
    c.id,
    c.title,
    c.community_id,
    comm.name as community_name,
    c.target_region,
    c.target_location_id,
    l.name as target_location_name,
    l.center_lat,
    l.center_lng,
    c.start_date,
    c.end_date,
    c.goal_participants,
    (select count(*) from public.challenge_participants cp where cp.challenge_id = c.id) as participants_count
  from public.prayer_challenges c
  join public.locations l on l.id = c.target_location_id
  left join public.communities comm on comm.id = c.community_id
  where c.status = 'active'
    and c.start_date <= now()
    and c.end_date >= now()
    and (
      p_community_id is null
      or c.community_id = p_community_id
    )
    and (
      c.community_id is null
      or (auth.uid() is not null and public.community_can_view(c.community_id, auth.uid()))
    )
  order by c.start_date desc
  limit greatest(p_limit, 1);
$$;

create or replace function public.prayer_challenge_rank_users(
  p_challenge_id uuid,
  p_limit integer default 20
)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  sessions_count bigint,
  total_duration_seconds bigint
)
language sql
stable
set search_path = public
as $$
  select
    ps.user_id,
    pr.username,
    pr.display_name,
    pr.avatar_url,
    count(*) as sessions_count,
    coalesce(sum(ps.duration_seconds), 0) as total_duration_seconds
  from public.prayer_sessions ps
  join public.prayer_challenges c on c.id = ps.challenge_id
  left join public.profiles pr on pr.id = ps.user_id
  where ps.challenge_id = p_challenge_id
    and ps.status = 'finished'
    and (
      (auth.uid() is not null and (c.community_id is null or public.community_can_view(c.community_id, auth.uid())))
      or (auth.uid() is null and c.community_id is null and c.status = 'active' and c.start_date <= now() and c.end_date >= now())
    )
  group by ps.user_id, pr.username, pr.display_name, pr.avatar_url
  order by total_duration_seconds desc, sessions_count desc
  limit greatest(p_limit, 1);
$$;

create or replace function public.prayer_challenge_rank_communities(
  p_challenge_id uuid,
  p_limit integer default 20
)
returns table (
  community_id uuid,
  name text,
  participants_count bigint
)
language sql
stable
set search_path = public
as $$
  select
    c.id as community_id,
    c.name,
    count(distinct cp.user_id) as participants_count
  from public.challenge_participants cp
  join public.prayer_challenges ch on ch.id = cp.challenge_id
  join public.community_members cm
    on cm.user_id = cp.user_id
   and cm.status = 'active'
  join public.communities c on c.id = cm.community_id
  where cp.challenge_id = p_challenge_id
    and (
      (auth.uid() is not null and (ch.community_id is null or public.community_can_view(ch.community_id, auth.uid())))
      or (auth.uid() is null and ch.community_id is null and ch.status = 'active' and ch.start_date <= now() and ch.end_date >= now())
    )
  group by c.id, c.name
  order by participants_count desc, c.name asc
  limit greatest(p_limit, 1);
$$;

create or replace function public.prayer_challenge_rank_countries(
  p_challenge_id uuid,
  p_limit integer default 20
)
returns table (
  country_code text,
  sessions_count bigint,
  total_duration_seconds bigint
)
language sql
stable
set search_path = public
as $$
  select
    nullif(split_part(l.path, '/', 3), '') as country_code,
    count(*) as sessions_count,
    coalesce(sum(ps.duration_seconds), 0) as total_duration_seconds
  from public.prayer_sessions ps
  join public.prayer_challenges ch on ch.id = ps.challenge_id
  join public.locations l on l.id = ps.location_id
  where ps.challenge_id = p_challenge_id
    and ps.status = 'finished'
    and (
      (auth.uid() is not null and (ch.community_id is null or public.community_can_view(ch.community_id, auth.uid())))
      or (auth.uid() is null and ch.community_id is null and ch.status = 'active' and ch.start_date <= now() and ch.end_date >= now())
    )
  group by country_code
  order by total_duration_seconds desc, sessions_count desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.join_prayer_challenge(uuid) to authenticated;
grant execute on function public.leave_prayer_challenge(uuid) to authenticated;
grant execute on function public.list_prayer_challenges(boolean, integer, integer) to anon, authenticated;
grant execute on function public.prayer_challenge_progress(uuid) to anon, authenticated;
grant execute on function public.prayer_challenges_for_map(uuid, integer) to anon, authenticated;
grant execute on function public.prayer_challenge_rank_users(uuid, integer) to anon, authenticated;
grant execute on function public.prayer_challenge_rank_communities(uuid, integer) to anon, authenticated;
grant execute on function public.prayer_challenge_rank_countries(uuid, integer) to anon, authenticated;

create or replace function public.trg_prayer_session_award_badges_and_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_hour int;
  v_total_seconds bigint;
  v_challenge_sessions bigint;
  v_location_id uuid;
  v_is_community boolean;
begin
  v_uid := new.user_id;
  if v_uid is null then
    return new;
  end if;

  v_hour := extract(hour from new.started_at);
  if v_hour between 0 and 4 then
    perform public.award_badge(v_uid, 'guardiao_madrugada');
  end if;

  select coalesce(sum(duration_seconds), 0)
  into v_total_seconds
  from public.prayer_sessions
  where user_id = v_uid
    and status = 'finished';
  if v_total_seconds >= 360000 then
    perform public.award_badge(v_uid, '100_horas_oracao');
  end if;

  if new.challenge_id is not null and new.status = 'finished' then
    select count(*)
    into v_challenge_sessions
    from public.prayer_sessions
    where user_id = v_uid
      and challenge_id = new.challenge_id
      and status = 'finished';
    if v_challenge_sessions = 5 then
      perform public.award_badge(v_uid, 'intercessor_fiel');
      select pc.community_id is not null into v_is_community from public.prayer_challenges pc where pc.id = new.challenge_id limit 1;
      select pc.target_location_id into v_location_id from public.prayer_challenges pc where pc.id = new.challenge_id limit 1;
      perform public.insert_notification_smart(
        p_user_id := v_uid,
        p_actor_id := null,
        p_type := 'challenge_milestone',
        p_title := 'Parabéns! 5 sessões no desafio',
        p_body := 'Você completou 5 sessões de oração neste desafio. Continue firme!',
        p_entity_id := new.challenge_id,
        p_entity_type := 'challenge',
        p_location_id := v_location_id,
        p_is_community := coalesce(v_is_community, false),
        p_bypass_scope := true,
        p_is_alert := false
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prayer_sessions_badges_notify on public.prayer_sessions;
create trigger trg_prayer_sessions_badges_notify
after insert or update on public.prayer_sessions
for each row execute function public.trg_prayer_session_award_badges_and_notify();

create or replace function public.send_prayer_challenge_daily_reminders(p_day date default (now() at time zone 'utc')::date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_sent integer := 0;
  r record;
begin
  v_day_start := (p_day::timestamp at time zone 'utc');
  v_day_end := ((p_day + 1)::timestamp at time zone 'utc');

  for r in
    select
      cp.user_id,
      ch.id as challenge_id,
      ch.title,
      ch.target_location_id as location_id,
      (ch.community_id is not null) as is_community
    from public.challenge_participants cp
    join public.prayer_challenges ch on ch.id = cp.challenge_id
    where ch.status = 'active'
      and ch.start_date <= now()
      and ch.end_date >= now()
      and not exists (
        select 1
        from public.prayer_sessions ps
        where ps.user_id = cp.user_id
          and ps.challenge_id = ch.id
          and ps.status = 'finished'
          and ps.started_at >= v_day_start
          and ps.started_at < v_day_end
      )
      and not exists (
        select 1
        from public.notifications n
        where n.user_id = cp.user_id
          and n.type = 'challenge_reminder'
          and n.entity_type = 'challenge'
          and n.entity_id = ch.id
          and n.created_at >= v_day_start
          and n.created_at < v_day_end
      )
    limit 10000
  loop
    perform public.insert_notification_smart(
      p_user_id := r.user_id,
      p_actor_id := null,
      p_type := 'challenge_reminder',
      p_title := 'Você ainda não orou hoje no desafio',
      p_body := 'Reserve alguns minutos para interceder em: ' || r.title,
      p_entity_id := r.challenge_id,
      p_entity_type := 'challenge',
      p_location_id := r.location_id,
      p_is_community := r.is_community,
      p_bypass_scope := true,
      p_is_alert := false
    );
    v_sent := v_sent + 1;
  end loop;

  return v_sent;
end;
$$;

grant execute on function public.send_prayer_challenge_daily_reminders(date) to service_role;

commit;
