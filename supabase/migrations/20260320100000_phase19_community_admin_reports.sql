begin;

drop policy if exists "community_prayer_runs_select_members" on public.community_prayer_schedule_runs;
create policy "community_prayer_runs_select_members"
on public.community_prayer_schedule_runs for select
using (
  public.community_is_admin(community_id, auth.uid())
  or assigned_user_id = auth.uid()
  or coalesce(auth.role(), '') = 'service_role'
);

create or replace function public.get_community_prayer_dashboard(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date)
)
returns table (
  total_duration_seconds bigint,
  total_sessions bigint,
  total_scales_completed bigint,
  total_scales_missed bigint,
  members jsonb
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_members jsonb;
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
  if p_from is null or p_to is null then
    raise exception 'range_required';
  end if;
  if p_to < p_from then
    raise exception 'invalid_range';
  end if;

  select
    coalesce(sum(ps.duration_seconds), 0)::bigint as total_duration_seconds,
    count(*)::bigint as total_sessions
  into
    total_duration_seconds,
    total_sessions
  from public.prayer_sessions ps
  where ps.community_id = p_community_id
    and ps.status = 'finished'
    and (ps.started_at at time zone 'utc')::date between p_from and p_to;

  select
    count(*) filter (where r.status = 'completed')::bigint as total_scales_completed,
    count(*) filter (where r.status = 'missed')::bigint as total_scales_missed
  into
    total_scales_completed,
    total_scales_missed
  from public.community_prayer_schedule_runs r
  where r.community_id = p_community_id
    and (r.starts_at at time zone 'utc')::date between p_from and p_to;

  with
    member_users as (
      select cm.user_id
      from public.community_members cm
      where cm.community_id = p_community_id
        and cm.status = 'active'
    ),
    ps_agg as (
      select
        ps.user_id,
        count(*)::bigint as sessions_count,
        coalesce(sum(ps.duration_seconds), 0)::bigint as total_duration_seconds
      from public.prayer_sessions ps
      where ps.community_id = p_community_id
        and ps.status = 'finished'
        and (ps.started_at at time zone 'utc')::date between p_from and p_to
      group by ps.user_id
    ),
    run_agg as (
      select
        r.assigned_user_id as user_id,
        count(*) filter (where r.status = 'completed')::bigint as completed_count,
        count(*) filter (where r.status = 'missed')::bigint as missed_count
      from public.community_prayer_schedule_runs r
      where r.community_id = p_community_id
        and (r.starts_at at time zone 'utc')::date between p_from and p_to
      group by r.assigned_user_id
    )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'user_id', m.user_id,
          'name', coalesce(nullif(trim(pr.display_name), ''), nullif(trim(pr.username), ''), 'Usuário'),
          'total_duration_seconds', coalesce(ps.total_duration_seconds, 0),
          'total_sessions', coalesce(ps.sessions_count, 0),
          'scales_completed', coalesce(ra.completed_count, 0),
          'scales_missed', coalesce(ra.missed_count, 0)
        )
        order by coalesce(ps.total_duration_seconds, 0) desc, coalesce(ps.sessions_count, 0) desc
      ),
      '[]'::jsonb
    )
  into v_members
  from member_users m
  left join public.profiles pr on pr.id = m.user_id
  left join ps_agg ps on ps.user_id = m.user_id
  left join run_agg ra on ra.user_id = m.user_id;

  members := v_members;
  return next;
end;
$$;

create or replace function public.get_community_schedule_report(
  p_community_id uuid,
  p_from timestamptz default (now() - interval '30 days'),
  p_to timestamptz default now(),
  p_limit integer default 200,
  p_offset integer default 0
)
returns table (
  run_id uuid,
  scheduled_start_at timestamptz,
  scheduled_end_at timestamptz,
  actual_start_at timestamptz,
  actual_end_at timestamptz,
  status text,
  planned_duration_seconds integer,
  actual_duration_seconds integer,
  prayer_note text,
  assigned_user_id uuid,
  assigned_user_name text,
  schedule_title text
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
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

  return query
  select
    r.id as run_id,
    r.starts_at as scheduled_start_at,
    r.ends_at as scheduled_end_at,
    ps.started_at as actual_start_at,
    ps.ended_at as actual_end_at,
    r.status,
    extract(epoch from (r.ends_at - r.starts_at))::int as planned_duration_seconds,
    ps.duration_seconds as actual_duration_seconds,
    coalesce(
      nullif(trim(ps.notes), ''),
      nullif(trim(ps.observations), ''),
      nullif(trim(ps.revelations), '')
    ) as prayer_note,
    r.assigned_user_id,
    coalesce(nullif(trim(pr.display_name), ''), nullif(trim(pr.username), ''), 'Usuário') as assigned_user_name,
    coalesce(nullif(trim(s.title), ''), 'Escala de oração') as schedule_title
  from public.community_prayer_schedule_runs r
  join public.community_prayer_schedules s on s.id = r.schedule_id
  left join public.prayer_sessions ps on ps.id = r.completed_session_id
  left join public.profiles pr on pr.id = r.assigned_user_id
  where r.community_id = p_community_id
    and r.starts_at >= p_from
    and r.starts_at <= p_to
  order by r.starts_at desc
  limit greatest(coalesce(p_limit, 200), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.get_community_prayer_dashboard(uuid, date, date) from public;
grant execute on function public.get_community_prayer_dashboard(uuid, date, date) to authenticated;

revoke all on function public.get_community_schedule_report(uuid, timestamptz, timestamptz, integer, integer) from public;
grant execute on function public.get_community_schedule_report(uuid, timestamptz, timestamptz, integer, integer) to authenticated;

commit;
