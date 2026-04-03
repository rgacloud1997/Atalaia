begin;

create extension if not exists unaccent;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'job_status'
  ) then
    create type public.job_status as enum ('queued', 'running', 'succeeded', 'failed', 'cancelled');
  end if;
end;
$$;

create table if not exists public.api_cache (
  key text primary key,
  value jsonb not null,
  tags text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists idx_api_cache_expires_at on public.api_cache (expires_at);
create index if not exists idx_api_cache_tags_gin on public.api_cache using gin (tags);

alter table public.api_cache enable row level security;

drop policy if exists "api_cache_service_only" on public.api_cache;
create policy "api_cache_service_only"
on public.api_cache for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create table if not exists public.job_queue (
  id bigint generated always as identity primary key,
  type text not null,
  payload jsonb not null default '{}'::jsonb,
  status public.job_status not null default 'queued',
  priority integer not null default 100,
  run_after timestamptz not null default now(),
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  locked_at timestamptz,
  locked_by text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_job_queue_status_run_after on public.job_queue (status, run_after, priority, id);
create index if not exists idx_job_queue_locked_at on public.job_queue (locked_at);

drop trigger if exists trg_job_queue_updated_at on public.job_queue;
create trigger trg_job_queue_updated_at
before update on public.job_queue
for each row execute function public.set_updated_at();

alter table public.job_queue enable row level security;

drop policy if exists "job_queue_service_only" on public.job_queue;
create policy "job_queue_service_only"
on public.job_queue for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create table if not exists public.rate_limits (
  key text primary key,
  window_start timestamptz not null,
  window_seconds integer not null,
  count integer not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists idx_rate_limits_updated_at on public.rate_limits (updated_at desc);

alter table public.rate_limits enable row level security;

drop policy if exists "rate_limits_service_only" on public.rate_limits;
create policy "rate_limits_service_only"
on public.rate_limits for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create or replace function public.cache_get_json(p_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  select c.value
  into v
  from public.api_cache c
  where c.key = p_key
    and c.expires_at > now()
  limit 1;
  return v;
end;
$$;

create or replace function public.cache_set_json(
  p_key text,
  p_value jsonb,
  p_ttl_seconds integer default 30,
  p_tags text[] default '{}'::text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ttl integer;
begin
  v_ttl := greatest(coalesce(p_ttl_seconds, 30), 1);
  insert into public.api_cache (key, value, tags, expires_at)
  values (p_key, p_value, coalesce(p_tags, '{}'::text[]), now() + make_interval(secs => v_ttl))
  on conflict (key)
  do update set
    value = excluded.value,
    tags = excluded.tags,
    expires_at = excluded.expires_at,
    created_at = now();
end;
$$;

create or replace function public.cache_cleanup_expired(p_limit integer default 5000)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows integer := 0;
begin
  delete from public.api_cache
  where key in (
    select key
    from public.api_cache
    where expires_at <= now()
    order by expires_at asc
    limit greatest(coalesce(p_limit, 5000), 1)
  );
  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

create or replace function public.cached_prayer_heatmap_for_map(
  p_window_hours integer default 24,
  p_community_id uuid default null,
  p_limit integer default 800,
  p_ttl_seconds integer default 30
)
returns table (
  location_id uuid,
  center_lat double precision,
  center_lng double precision,
  prayer_count integer,
  urgency_score integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_key text;
  v_cached jsonb;
  v_data jsonb;
begin
  v_key :=
    'heatmap:' ||
    greatest(coalesce(p_window_hours, 24), 1)::text || ':' ||
    coalesce(p_community_id::text, '') || ':' ||
    greatest(coalesce(p_limit, 800), 1)::text;

  v_cached := public.cache_get_json(v_key);
  if v_cached is not null then
    return query
      select *
      from jsonb_to_recordset(v_cached) as x(
        location_id uuid,
        center_lat double precision,
        center_lng double precision,
        prayer_count integer,
        urgency_score integer
      );
    return;
  end if;

  select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
  into v_data
  from public.prayer_heatmap_for_map(
    p_window_hours := p_window_hours,
    p_community_id := p_community_id,
    p_limit := p_limit
  ) as t;

  perform public.cache_set_json(
    p_key := v_key,
    p_value := v_data,
    p_ttl_seconds := p_ttl_seconds,
    p_tags := array['map', 'heatmap']
  );

  return query
    select *
    from jsonb_to_recordset(v_data) as x(
      location_id uuid,
      center_lat double precision,
      center_lng double precision,
      prayer_count integer,
      urgency_score integer
    );
end;
$$;

create or replace function public.cached_prayer_challenges_for_map(
  p_community_id uuid default null,
  p_limit integer default 60,
  p_ttl_seconds integer default 30
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
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_key text;
  v_cached jsonb;
  v_data jsonb;
begin
  v_key :=
    'challenge_pins:' ||
    coalesce(p_community_id::text, '') || ':' ||
    greatest(coalesce(p_limit, 60), 1)::text;

  v_cached := public.cache_get_json(v_key);
  if v_cached is not null then
    return query
      select *
      from jsonb_to_recordset(v_cached) as x(
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
      );
    return;
  end if;

  select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
  into v_data
  from public.prayer_challenges_for_map(
    p_community_id := p_community_id,
    p_limit := p_limit
  ) as t;

  perform public.cache_set_json(
    p_key := v_key,
    p_value := v_data,
    p_ttl_seconds := p_ttl_seconds,
    p_tags := array['map', 'pins', 'challenges']
  );

  return query
    select *
    from jsonb_to_recordset(v_data) as x(
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
    );
end;
$$;

create or replace function public.rate_limit_check(
  p_key text,
  p_window_seconds integer,
  p_max integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_window integer;
  v_max integer;
  v_start timestamptz;
  v_count integer;
begin
  v_window := greatest(coalesce(p_window_seconds, 60), 1);
  v_max := greatest(coalesce(p_max, 1), 1);
  v_start := date_trunc('second', now()) - make_interval(secs => mod(extract(epoch from now())::int, v_window));

  insert into public.rate_limits (key, window_start, window_seconds, count, updated_at)
  values (p_key, v_start, v_window, 1, now())
  on conflict (key)
  do update set
    window_start = case when rate_limits.window_start = excluded.window_start and rate_limits.window_seconds = excluded.window_seconds
      then rate_limits.window_start
      else excluded.window_start
    end,
    window_seconds = excluded.window_seconds,
    count = case when rate_limits.window_start = excluded.window_start and rate_limits.window_seconds = excluded.window_seconds
      then rate_limits.count + 1
      else 1
    end,
    updated_at = now()
  returning count into v_count;

  return v_count <= v_max;
end;
$$;

create or replace function public.guard_rate_limit(
  p_action text,
  p_user_id uuid,
  p_window_seconds integer,
  p_max integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
  ok boolean;
begin
  if p_user_id is null then
    return;
  end if;
  v_key := coalesce(p_action, 'action') || ':' || p_user_id::text;
  ok := public.rate_limit_check(v_key, p_window_seconds, p_max);
  if not ok then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public.trg_posts_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.guard_rate_limit('posts_insert', new.user_id, 60, 15);
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.posts') is not null then
    execute 'drop trigger if exists trg_posts_rate_limit on public.posts';
    execute 'create trigger trg_posts_rate_limit before insert on public.posts for each row execute function public.trg_posts_rate_limit()';
  end if;
end
$$;

create or replace function public.trg_region_prayers_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.guard_rate_limit('region_prayers_insert', new.user_id, 60, 30);
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.region_prayers') is not null then
    execute 'drop trigger if exists trg_region_prayers_rate_limit on public.region_prayers';
    execute 'create trigger trg_region_prayers_rate_limit before insert on public.region_prayers for each row execute function public.trg_region_prayers_rate_limit()';
  end if;
end
$$;

create or replace function public.enqueue_job(
  p_type text,
  p_payload jsonb default '{}'::jsonb,
  p_run_after timestamptz default now(),
  p_priority integer default 100,
  p_max_attempts integer default 5
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
begin
  if coalesce(p_type, '') = '' then
    raise exception 'job_type_required';
  end if;

  insert into public.job_queue (type, payload, status, run_after, priority, max_attempts)
  values (
    p_type,
    coalesce(p_payload, '{}'::jsonb),
    'queued'::public.job_status,
    coalesce(p_run_after, now()),
    greatest(coalesce(p_priority, 100), 0),
    greatest(coalesce(p_max_attempts, 5), 1)
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.trg_ai_analyze_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payload jsonb;
begin
  v_payload := jsonb_build_object('post_id', new.id);
  perform public.enqueue_job('ai_analyze_post', v_payload, now(), 50, 5);
  return new;
end;
$$;

create or replace function public.process_job_queue(
  p_limit integer default 50,
  p_worker_id text default null
)
returns table (
  job_id bigint,
  job_type text,
  status public.job_status
)
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_worker text := coalesce(nullif(p_worker_id, ''), 'worker');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_window_hours integer;
  v_community_id uuid;
  v_day date;
  v_status public.job_status;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service_role_required';
  end if;

  for r in
    select *
    from public.job_queue
    where status = 'queued'::public.job_status
      and run_after <= now()
      and attempts < max_attempts
    order by priority asc, id asc
    for update skip locked
    limit v_limit
  loop
    update public.job_queue
    set
      status = 'running'::public.job_status,
      locked_at = now(),
      locked_by = v_worker,
      attempts = attempts + 1
    where id = r.id;

    begin
      if r.type = 'refresh_prayer_heatmap' then
        v_window_hours := coalesce((r.payload->>'window_hours')::int, 24);
        v_community_id := nullif(r.payload->>'community_id', '')::uuid;
        perform public.refresh_prayer_heatmap(v_window_hours, v_community_id);
      elsif r.type = 'ai_analyze_post' then
        perform public.ai_upsert_post_analysis(nullif(r.payload->>'post_id', '')::uuid);
      elsif r.type = 'send_prayer_challenge_daily_reminders' then
        v_day := coalesce((r.payload->>'day')::date, (now() at time zone 'utc')::date);
        perform public.send_prayer_challenge_daily_reminders(v_day);
      elsif r.type = 'cleanup_api_cache' then
        perform public.cache_cleanup_expired(coalesce((r.payload->>'limit')::int, 5000));
      end if;

      update public.job_queue
      set
        status = 'succeeded'::public.job_status,
        locked_at = null,
        locked_by = null,
        last_error = null
      where id = r.id;
    exception
      when others then
        update public.job_queue
        set
          status = case when attempts >= max_attempts then 'failed'::public.job_status else 'queued'::public.job_status end,
          run_after = case when attempts >= max_attempts then run_after else now() + interval '30 seconds' end,
          locked_at = null,
          locked_by = null,
          last_error = sqlerrm
        where id = r.id;
    end;

    job_id := r.id;
    job_type := r.type;
    select q.status into v_status from public.job_queue q where q.id = r.id;
    status := v_status;
    return next;
  end loop;
end;
$$;

create table if not exists public.prayer_sessions_archive (
  id uuid primary key,
  user_id uuid not null,
  location_id uuid not null,
  location_level public.location_level not null,
  challenge_id uuid,
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_seconds integer not null,
  status text not null,
  created_at timestamptz not null,
  archived_at timestamptz not null default now()
);

create index if not exists idx_prayer_sessions_archive_user_created_at on public.prayer_sessions_archive (user_id, created_at desc);
create index if not exists idx_prayer_sessions_archive_location_created_at on public.prayer_sessions_archive (location_id, created_at desc);

alter table public.prayer_sessions_archive enable row level security;

drop policy if exists "prayer_sessions_archive_service_only" on public.prayer_sessions_archive;
create policy "prayer_sessions_archive_service_only"
on public.prayer_sessions_archive for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create or replace function public.archive_prayer_sessions(p_before timestamptz, p_limit integer default 20000)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows integer := 0;
begin
  if p_before is null then
    return 0;
  end if;

  with moved as (
    delete from public.prayer_sessions s
    where s.id in (
      select id
      from public.prayer_sessions
      where created_at < p_before
      order by created_at asc
      limit greatest(coalesce(p_limit, 20000), 1)
    )
    returning *
  )
  insert into public.prayer_sessions_archive (
    id,
    user_id,
    location_id,
    location_level,
    challenge_id,
    started_at,
    ended_at,
    duration_seconds,
    status,
    created_at,
    archived_at
  )
  select
    m.id,
    m.user_id,
    m.location_id,
    m.location_level,
    m.challenge_id,
    m.started_at,
    m.ended_at,
    m.duration_seconds,
    m.status,
    m.created_at,
    now()
  from moved m;

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

do $$
begin
  if to_regclass('public.prayer_sessions') is not null then
    execute 'create index if not exists idx_prayer_sessions_status_started_at on public.prayer_sessions (status, started_at desc)';
  end if;
  if to_regclass('public.notifications') is not null then
    execute 'create index if not exists idx_notifications_created_at on public.notifications (created_at desc)';
  end if;
  if to_regclass('public.community_messages') is not null then
    execute 'create index if not exists idx_community_messages_created_at on public.community_messages (created_at desc)';
  end if;
end
$$;

revoke all on function public.cache_get_json(text) from public, anon, authenticated;
revoke all on function public.cache_set_json(text, jsonb, integer, text[]) from public, anon, authenticated;
revoke all on function public.cache_cleanup_expired(integer) from public, anon, authenticated;
revoke all on function public.enqueue_job(text, jsonb, timestamptz, integer, integer) from public, anon, authenticated;
revoke all on function public.process_job_queue(integer, text) from public, anon, authenticated;
revoke all on function public.rate_limit_check(text, integer, integer) from public, anon, authenticated;
revoke all on function public.guard_rate_limit(text, uuid, integer, integer) from public, anon, authenticated;
revoke all on function public.archive_prayer_sessions(timestamptz, integer) from public, anon, authenticated;

revoke all on function public.trg_posts_rate_limit() from public, anon;
revoke all on function public.trg_region_prayers_rate_limit() from public, anon;

revoke all on function public.cached_prayer_heatmap_for_map(integer, uuid, integer, integer) from public;
revoke all on function public.cached_prayer_challenges_for_map(uuid, integer, integer) from public;

grant execute on function public.cached_prayer_heatmap_for_map(integer, uuid, integer, integer) to anon, authenticated;
grant execute on function public.cached_prayer_challenges_for_map(uuid, integer, integer) to anon, authenticated;

grant execute on function public.trg_posts_rate_limit() to authenticated, service_role;
grant execute on function public.trg_region_prayers_rate_limit() to authenticated, service_role;

grant execute on function public.cache_get_json(text) to service_role;
grant execute on function public.cache_set_json(text, jsonb, integer, text[]) to service_role;
grant execute on function public.cache_cleanup_expired(integer) to service_role;
grant execute on function public.enqueue_job(text, jsonb, timestamptz, integer, integer) to service_role;
grant execute on function public.process_job_queue(integer, text) to service_role;
grant execute on function public.archive_prayer_sessions(timestamptz, integer) to service_role;

commit;
