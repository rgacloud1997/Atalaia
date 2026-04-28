begin;

create or replace function public.get_prayer_by_user_detailed(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date)
)
returns table (
  user_id uuid,
  user_name text,
  user_avatar_url text,
  turns_assigned integer,
  turns_completed integer,
  turns_missed integer,
  turns_cancelled integer,
  completion_percentage double precision,
  avg_duration_minutes integer,
  last_completed_at timestamptz,
  last_assigned_at timestamptz,
  pending_runs_count integer,
  common_hours jsonb,
  streak_days integer
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
  if p_from is null or p_to is null then
    raise exception 'range_required';
  end if;
  if p_to < p_from then
    raise exception 'invalid_range';
  end if;

  return query
  with
    runs_in_range as (
      select
        r.assigned_user_id as user_id,
        r.status,
        r.starts_at,
        r.completed_session_id
      from public.community_prayer_schedule_runs r
      where r.community_id = p_community_id
        and (r.starts_at at time zone 'utc')::date between p_from and p_to
    ),
    run_agg as (
      select
        r.user_id,
        count(*)::int as turns_assigned,
        count(*) filter (where r.status = 'completed')::int as turns_completed,
        count(*) filter (where r.status = 'missed')::int as turns_missed,
        count(*) filter (where r.status = 'cancelled')::int as turns_cancelled,
        max(r.starts_at) as last_assigned_at,
        count(*) filter (where r.status = 'scheduled')::int as pending_runs_count
      from runs_in_range r
      group by r.user_id
    ),
    sessions_agg as (
      select
        r.user_id,
        max(ps.started_at) as last_completed_at,
        coalesce(round(avg(ps.duration_seconds) / 60.0), 0)::int as avg_duration_minutes
      from runs_in_range r
      join public.prayer_sessions ps on ps.id = r.completed_session_id
      where r.status = 'completed'
      group by r.user_id
    ),
    common_hours_agg as (
      select
        y.user_id,
        coalesce(
          jsonb_agg(y.hour_label order by y.cnt desc, y.hour_int asc),
          '[]'::jsonb
        ) as common_hours
      from (
        select
          x.user_id,
          x.hour_int,
          lpad(x.hour_int::text, 2, '0') || ':00' as hour_label,
          x.cnt
        from (
          select
            g.user_id,
            g.hour_int,
            g.cnt,
            row_number() over (
              partition by g.user_id
              order by g.cnt desc, g.hour_int asc
            ) as rn
          from (
            select
              r.user_id,
              extract(hour from (r.starts_at at time zone 'utc'))::int as hour_int,
              count(*)::int as cnt
            from runs_in_range r
            group by r.user_id, extract(hour from (r.starts_at at time zone 'utc'))
          ) g
        ) x
        where x.rn <= 3
      ) y
      group by y.user_id
    ),
    streaks as (
      select
        y.user_id,
        coalesce(max(y.streak_len), 0)::int as streak_days
      from (
        select
          d.user_id,
          count(*)::int as streak_len
        from (
          select
            distinct r.user_id,
            (r.starts_at at time zone 'utc')::date as day,
            ((r.starts_at at time zone 'utc')::date - row_number() over (
              partition by r.user_id
              order by (r.starts_at at time zone 'utc')::date
            )::int) as grp
          from runs_in_range r
          where r.status = 'completed'
        ) d
        group by d.user_id, d.grp
      ) y
      group by y.user_id
    )
  select
    ra.user_id,
    coalesce(nullif(trim(pr.display_name), ''), nullif(trim(pr.username), ''), 'Usuário') as user_name,
    pr.avatar_url as user_avatar_url,
    ra.turns_assigned,
    ra.turns_completed,
    ra.turns_missed,
    ra.turns_cancelled,
    coalesce(ra.turns_completed::double precision / nullif((ra.turns_completed + ra.turns_missed)::double precision, 0), 0.0) * 100.0 as completion_percentage,
    coalesce(sa.avg_duration_minutes, 0) as avg_duration_minutes,
    sa.last_completed_at,
    ra.last_assigned_at,
    ra.pending_runs_count,
    coalesce(cha.common_hours, '[]'::jsonb) as common_hours,
    coalesce(st.streak_days, 0) as streak_days
  from run_agg ra
  left join public.profiles pr on pr.id = ra.user_id
  left join sessions_agg sa on sa.user_id = ra.user_id
  left join common_hours_agg cha on cha.user_id = ra.user_id
  left join streaks st on st.user_id = ra.user_id
  order by ra.turns_completed desc, ra.turns_assigned desc, user_name asc;
end;
$$;

create or replace function public.get_prayers_by_completion_status(
  p_community_id uuid,
  p_from timestamptz default (now() - interval '30 days'),
  p_to timestamptz default now(),
  p_limit integer default 200,
  p_offset integer default 0
)
returns table (
  run_id uuid,
  status text,
  scheduled_at timestamptz,
  actual_at timestamptz,
  target_name text,
  community_name text,
  user_name text,
  planned_duration integer,
  actual_duration integer,
  notes text
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
    r.status,
    r.starts_at as scheduled_at,
    ps.started_at as actual_at,
    coalesce(nullif(trim(pt.title), ''), 'Sem alvo') as target_name,
    c.name as community_name,
    coalesce(nullif(trim(pr.display_name), ''), nullif(trim(pr.username), ''), 'Usuário') as user_name,
    extract(epoch from (r.ends_at - r.starts_at))::int / 60 as planned_duration,
    case
      when ps.duration_seconds is null then null
      else greatest(floor(ps.duration_seconds / 60.0), 0)::int
    end as actual_duration,
    coalesce(
      nullif(trim(ps.notes), ''),
      nullif(trim(ps.observations), ''),
      nullif(trim(ps.revelations), ''),
      nullif(trim(r.notes), '')
    ) as notes
  from public.community_prayer_schedule_runs r
  join public.community_prayer_schedules s on s.id = r.schedule_id
  join public.communities c on c.id = r.community_id
  left join public.prayer_targets pt on pt.id = s.prayer_target_id
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

create or replace function public.get_coverage_by_region(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date)
)
returns table (
  region_id uuid,
  region_name text,
  total_runs integer,
  completed_runs integer,
  missed_runs integer,
  coverage_percentage double precision,
  unique_users integer,
  avg_duration integer,
  rank integer
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
  if p_from is null or p_to is null then
    raise exception 'range_required';
  end if;
  if p_to < p_from then
    raise exception 'invalid_range';
  end if;

  return query
  with
    user_primary_region as (
      select x.user_id, x.location_id as region_id
      from (
        select
          g.user_id,
          g.location_id,
          g.cnt,
          g.last_started_at,
          row_number() over (
            partition by g.user_id
            order by g.cnt desc, g.last_started_at desc
          ) as rn
        from (
          select
            ps.user_id,
            ps.location_id,
            count(*)::int as cnt,
            max(ps.started_at) as last_started_at
          from public.prayer_sessions ps
          where ps.community_id = p_community_id
            and ps.status = 'finished'
            and (ps.started_at at time zone 'utc')::date between p_from and p_to
          group by ps.user_id, ps.location_id
        ) g
      ) x
      where x.rn = 1
    ),
    base as (
      select
        coalesce(ps.location_id, upr.region_id) as region_id,
        r.assigned_user_id as user_id,
        r.status,
        ps.duration_seconds
      from public.community_prayer_schedule_runs r
      left join public.prayer_sessions ps on ps.id = r.completed_session_id
      left join user_primary_region upr on upr.user_id = r.assigned_user_id
      where r.community_id = p_community_id
        and (r.starts_at at time zone 'utc')::date between p_from and p_to
        and coalesce(ps.location_id, upr.region_id) is not null
    ),
    agg as (
      select
        b.region_id,
        count(*)::int as total_runs,
        count(*) filter (where b.status = 'completed')::int as completed_runs,
        count(*) filter (where b.status = 'missed')::int as missed_runs,
        count(distinct b.user_id)::int as unique_users,
        coalesce(round(avg(b.duration_seconds) / 60.0), 0)::int as avg_duration
      from base b
      group by b.region_id
    ),
    ranked as (
      select
        a.*,
        dense_rank() over (order by a.completed_runs desc, a.total_runs desc) as rank
      from agg a
    )
  select
    r.region_id,
    coalesce(l.name, 'Desconhecida') as region_name,
    r.total_runs,
    r.completed_runs,
    r.missed_runs,
    coalesce(r.completed_runs::double precision / nullif(r.total_runs::double precision, 0), 0.0) * 100.0 as coverage_percentage,
    r.unique_users,
    r.avg_duration,
    r.rank
  from ranked r
  left join public.locations l on l.id = r.region_id
  order by r.rank asc, region_name asc;
end;
$$;

revoke all on function public.get_prayer_by_user_detailed(uuid, date, date) from public;
grant execute on function public.get_prayer_by_user_detailed(uuid, date, date) to authenticated;

revoke all on function public.get_prayers_by_completion_status(uuid, timestamptz, timestamptz, integer, integer) from public;
grant execute on function public.get_prayers_by_completion_status(uuid, timestamptz, timestamptz, integer, integer) to authenticated;

revoke all on function public.get_coverage_by_region(uuid, date, date) from public;
grant execute on function public.get_coverage_by_region(uuid, date, date) to authenticated;

commit;
