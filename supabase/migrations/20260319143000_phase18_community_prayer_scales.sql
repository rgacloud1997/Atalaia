begin;

alter table if exists public.prayer_sessions
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists trg_prayer_sessions_updated_at on public.prayer_sessions;
do $$
begin
  if to_regclass('public.prayer_sessions') is not null then
    execute 'create trigger trg_prayer_sessions_updated_at before update on public.prayer_sessions for each row execute function public.set_updated_at()';
  end if;
end
$$;

alter table if exists public.prayer_sessions
  add column if not exists observations text,
  add column if not exists revelations text,
  add column if not exists notes text,
  add column if not exists community_id uuid references public.communities(id) on delete set null;

create table if not exists public.community_prayer_schedules (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  kind text not null default 'one_time',
  timezone text not null default 'UTC',
  weekday smallint,
  start_time time,
  duration_minutes integer not null default 60,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_prayer_schedules_kind_check check (kind in ('weekly_fixed', 'one_time')),
  constraint community_prayer_schedules_weekday_check check (weekday is null or (weekday between 0 and 6)),
  constraint community_prayer_schedules_duration_check check (duration_minutes between 1 and 720)
);

create index if not exists idx_comm_prayer_schedules_community_active on public.community_prayer_schedules (community_id, is_active);

drop trigger if exists trg_comm_prayer_schedules_updated_at on public.community_prayer_schedules;
create trigger trg_comm_prayer_schedules_updated_at
before update on public.community_prayer_schedules
for each row execute function public.set_updated_at();

alter table public.community_prayer_schedules enable row level security;

drop policy if exists "community_prayer_schedules_select_members" on public.community_prayer_schedules;
create policy "community_prayer_schedules_select_members"
on public.community_prayer_schedules for select
using (
  public.community_can_view(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "community_prayer_schedules_write_admin" on public.community_prayer_schedules;
create policy "community_prayer_schedules_write_admin"
on public.community_prayer_schedules for all
using (
  public.community_is_admin(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  public.community_is_admin(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

create table if not exists public.community_prayer_schedule_runs (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.community_prayer_schedules(id) on delete cascade,
  community_id uuid not null references public.communities(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  assigned_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'scheduled',
  notes text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_session_id uuid references public.prayer_sessions(id) on delete set null,
  constraint community_prayer_schedule_runs_status_check check (status in ('scheduled', 'completed', 'missed', 'cancelled')),
  constraint community_prayer_schedule_runs_time_check check (ends_at > starts_at)
);

create index if not exists idx_comm_prayer_runs_community_starts_at on public.community_prayer_schedule_runs (community_id, starts_at desc);
create index if not exists idx_comm_prayer_runs_assigned_starts_at on public.community_prayer_schedule_runs (assigned_user_id, starts_at desc);
create index if not exists idx_comm_prayer_runs_schedule_starts_at on public.community_prayer_schedule_runs (schedule_id, starts_at desc);

drop trigger if exists trg_comm_prayer_runs_updated_at on public.community_prayer_schedule_runs;
create trigger trg_comm_prayer_runs_updated_at
before update on public.community_prayer_schedule_runs
for each row execute function public.set_updated_at();

alter table public.community_prayer_schedule_runs enable row level security;

drop policy if exists "community_prayer_runs_select_members" on public.community_prayer_schedule_runs;
create policy "community_prayer_runs_select_members"
on public.community_prayer_schedule_runs for select
using (
  public.community_can_view(community_id, auth.uid())
  or assigned_user_id = auth.uid()
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "community_prayer_runs_write_admin" on public.community_prayer_schedule_runs;
create policy "community_prayer_runs_write_admin"
on public.community_prayer_schedule_runs for all
using (
  public.community_is_admin(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  public.community_is_admin(community_id, auth.uid())
  or coalesce(auth.role(), '') = 'service_role'
);

alter table if exists public.prayer_sessions
  add column if not exists schedule_run_id uuid references public.community_prayer_schedule_runs(id) on delete set null;

create index if not exists idx_prayer_sessions_community_started_at on public.prayer_sessions (community_id, started_at desc);
create index if not exists idx_prayer_sessions_schedule_run on public.prayer_sessions (schedule_run_id);

create or replace function public.trg_prayer_sessions_sync_run_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.schedule_run_id is null then
    return new;
  end if;

  if coalesce(new.status, '') = 'finished' and new.ended_at is not null then
    update public.community_prayer_schedule_runs
    set
      status = 'completed',
      completed_session_id = new.id
    where id = new.schedule_run_id
      and status <> 'completed';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prayer_sessions_sync_run_completion on public.prayer_sessions;
do $$
begin
  if to_regclass('public.prayer_sessions') is not null then
    execute 'create trigger trg_prayer_sessions_sync_run_completion after update of status, ended_at on public.prayer_sessions for each row execute function public.trg_prayer_sessions_sync_run_completion()';
  end if;
end
$$;

create or replace function public.upsert_community_prayer_schedule(
  p_schedule_id uuid,
  p_community_id uuid,
  p_title text,
  p_kind text default 'one_time',
  p_timezone text default 'UTC',
  p_weekday integer default null,
  p_start_time time default null,
  p_duration_minutes integer default 60,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_kind text := coalesce(nullif(trim(lower(p_kind)), ''), 'one_time');
  v_title text := coalesce(nullif(trim(p_title), ''), '');
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;
  if p_community_id is null then
    raise exception 'community_required';
  end if;
  if not public.community_is_admin(p_community_id, v_uid) then
    raise exception 'not_allowed';
  end if;
  if v_title = '' then
    raise exception 'title_required';
  end if;
  if v_kind not in ('weekly_fixed', 'one_time') then
    raise exception 'invalid_kind';
  end if;

  if p_schedule_id is null then
    insert into public.community_prayer_schedules (
      community_id,
      title,
      kind,
      timezone,
      weekday,
      start_time,
      duration_minutes,
      is_active,
      created_by
    )
    values (
      p_community_id,
      v_title,
      v_kind,
      coalesce(nullif(trim(p_timezone), ''), 'UTC'),
      p_weekday,
      p_start_time,
      greatest(coalesce(p_duration_minutes, 60), 1),
      coalesce(p_is_active, true),
      v_uid
    )
    returning id into v_id;
  else
    update public.community_prayer_schedules
    set
      title = v_title,
      kind = v_kind,
      timezone = coalesce(nullif(trim(p_timezone), ''), timezone),
      weekday = p_weekday,
      start_time = p_start_time,
      duration_minutes = greatest(coalesce(p_duration_minutes, duration_minutes), 1),
      is_active = coalesce(p_is_active, is_active)
    where id = p_schedule_id
      and community_id = p_community_id;

    if not found then
      raise exception 'schedule_not_found';
    end if;
    v_id := p_schedule_id;
  end if;

  return v_id;
end;
$$;

create or replace function public.community_prayer_mark_run_missed(p_run_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.community_prayer_schedule_runs
  set status = 'missed'
  where id = p_run_id
    and status = 'scheduled'
    and ends_at <= now();
end;
$$;

create or replace function public.community_prayer_send_run_reminder(p_run_id uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_type text;
  v_title text;
  v_body text;
begin
  select
    run.id as run_id,
    run.community_id,
    run.starts_at,
    run.assigned_user_id,
    run.status,
    s.title as schedule_title,
    c.location_id as community_location_id
  into r
  from public.community_prayer_schedule_runs run
  join public.community_prayer_schedules s on s.id = run.schedule_id
  join public.communities c on c.id = run.community_id
  where run.id = p_run_id;

  if r.run_id is null then
    return;
  end if;
  if r.status <> 'scheduled' then
    return;
  end if;

  v_type := case
    when coalesce(nullif(trim(lower(p_kind)), ''), '') = '24h' then 'scale_reminder_24h'
    else 'scale_reminder_1h'
  end;

  v_title := 'Lembrete de escala';
  v_body := coalesce(nullif(trim(r.schedule_title), ''), 'Oração') || ' • ' || to_char(r.starts_at at time zone 'utc', 'DD/MM HH24:MI') || ' UTC';

  perform public.insert_notification_smart(
    p_user_id := r.assigned_user_id,
    p_actor_id := null,
    p_type := v_type,
    p_title := v_title,
    p_body := v_body,
    p_entity_id := r.run_id,
    p_entity_type := 'community_prayer_run',
    p_location_id := r.community_location_id,
    p_is_community := true,
    p_bypass_scope := true,
    p_is_alert := false
  );
end;
$$;

create or replace function public.create_community_prayer_run_simple(
  p_community_id uuid,
  p_title text,
  p_starts_at timestamptz,
  p_duration_minutes integer,
  p_assigned_user_id uuid,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_schedule_id uuid;
  v_run_id uuid;
  v_ends_at timestamptz;
  v_run_after_24h timestamptz;
  v_run_after_1h timestamptz;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;
  if p_community_id is null then
    raise exception 'community_required';
  end if;
  if not public.community_is_admin(p_community_id, v_uid) then
    raise exception 'not_allowed';
  end if;
  if p_assigned_user_id is null then
    raise exception 'assigned_user_required';
  end if;

  if not exists (
    select 1
    from public.community_members cm
    where cm.community_id = p_community_id
      and cm.user_id = p_assigned_user_id
      and cm.status = 'active'
  ) then
    raise exception 'assigned_user_not_member';
  end if;

  v_schedule_id := public.upsert_community_prayer_schedule(
    null,
    p_community_id,
    p_title,
    'one_time',
    'UTC',
    null,
    null,
    greatest(coalesce(p_duration_minutes, 60), 1),
    true
  );

  v_ends_at := p_starts_at + make_interval(mins => greatest(coalesce(p_duration_minutes, 60), 1));

  insert into public.community_prayer_schedule_runs (
    schedule_id,
    community_id,
    starts_at,
    ends_at,
    assigned_user_id,
    status,
    notes,
    created_by
  )
  values (
    v_schedule_id,
    p_community_id,
    p_starts_at,
    v_ends_at,
    p_assigned_user_id,
    'scheduled',
    nullif(trim(coalesce(p_notes, '')), ''),
    v_uid
  )
  returning id into v_run_id;

  v_run_after_24h := p_starts_at - interval '24 hours';
  v_run_after_1h := p_starts_at - interval '1 hour';

  if v_run_after_24h > now() then
    perform public.enqueue_job(
      'community_prayer_run_reminder',
      jsonb_build_object('run_id', v_run_id, 'kind', '24h'),
      v_run_after_24h,
      40,
      5
    );
  end if;

  if v_run_after_1h > now() then
    perform public.enqueue_job(
      'community_prayer_run_reminder',
      jsonb_build_object('run_id', v_run_id, 'kind', '1h'),
      v_run_after_1h,
      40,
      5
    );
  end if;

  perform public.enqueue_job(
    'community_prayer_run_mark_missed',
    jsonb_build_object('run_id', v_run_id),
    v_ends_at + interval '5 minutes',
    80,
    3
  );

  return v_run_id;
end;
$$;

create or replace function public.community_prayer_report(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 6),
  p_to date default ((now() at time zone 'utc')::date)
)
returns table (
  day date,
  scheduled_count integer,
  completed_count integer,
  missed_count integer,
  total_duration_seconds bigint
)
language sql
security definer
stable
set search_path = public
as $$
  select
    d.day,
    coalesce(sum(case when r.id is null then 0 else 1 end), 0)::int as scheduled_count,
    coalesce(sum(case when r.status = 'completed' then 1 else 0 end), 0)::int as completed_count,
    coalesce(sum(case when r.status = 'missed' then 1 else 0 end), 0)::int as missed_count,
    coalesce(sum(case when r.status = 'completed' then ps.duration_seconds else 0 end), 0)::bigint as total_duration_seconds
  from (
    select generate_series(p_from, p_to, interval '1 day')::date as day
  ) d
  left join public.community_prayer_schedule_runs r
    on r.community_id = p_community_id
   and (r.starts_at at time zone 'utc')::date = d.day
  left join public.prayer_sessions ps
    on ps.id = r.completed_session_id
  where public.community_is_admin(p_community_id, auth.uid())
  group by d.day
  order by d.day asc;
$$;

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
  if not exists (select 1 from public.communities c where c.id = p_community_id and c.owner_id = v_uid) then
    raise exception 'not_allowed';
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

create or replace function public.transfer_community_ownership(
  p_community_id uuid,
  p_new_owner_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;
  if p_community_id is null or p_new_owner_id is null then
    raise exception 'invalid_args';
  end if;
  if not exists (select 1 from public.communities c where c.id = p_community_id and c.owner_id = v_uid) then
    raise exception 'not_allowed';
  end if;
  if not exists (
    select 1
    from public.community_members cm
    where cm.community_id = p_community_id
      and cm.user_id = p_new_owner_id
      and cm.status = 'active'
  ) then
    raise exception 'new_owner_not_member';
  end if;

  update public.communities
  set owner_id = p_new_owner_id
  where id = p_community_id;

  update public.community_members
  set role = 'admin'
  where community_id = p_community_id
    and user_id = p_new_owner_id;

  update public.community_members
  set role = 'admin'
  where community_id = p_community_id
    and user_id = v_uid;
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
  v_run_id uuid;
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
      elsif r.type = 'community_prayer_run_reminder' then
        v_run_id := nullif(r.payload->>'run_id', '')::uuid;
        perform public.community_prayer_send_run_reminder(v_run_id, r.payload->>'kind');
      elsif r.type = 'community_prayer_run_mark_missed' then
        v_run_id := nullif(r.payload->>'run_id', '')::uuid;
        perform public.community_prayer_mark_run_missed(v_run_id);
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

revoke all on function public.upsert_community_prayer_schedule(uuid, uuid, text, text, text, integer, time, integer, boolean) from public;
grant execute on function public.upsert_community_prayer_schedule(uuid, uuid, text, text, text, integer, time, integer, boolean) to authenticated;

revoke all on function public.create_community_prayer_run_simple(uuid, text, timestamptz, integer, uuid, text) from public;
grant execute on function public.create_community_prayer_run_simple(uuid, text, timestamptz, integer, uuid, text) to authenticated;

revoke all on function public.community_prayer_report(uuid, date, date) from public;
grant execute on function public.community_prayer_report(uuid, date, date) to authenticated;

revoke all on function public.set_community_member_role(uuid, uuid, text) from public;
grant execute on function public.set_community_member_role(uuid, uuid, text) to authenticated;

revoke all on function public.transfer_community_ownership(uuid, uuid) from public;
grant execute on function public.transfer_community_ownership(uuid, uuid) to authenticated;

commit;
