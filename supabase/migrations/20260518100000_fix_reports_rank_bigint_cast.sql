-- Fix: dense_rank() returns bigint, but get_coverage_by_region,
-- get_coverage_by_target and get_failure_analysis declared `rank integer`
-- in their RETURNS TABLE. Calling any of them raised:
--   ERROR: structure of query does not match function result type
--   DETAIL: Returned type bigint does not match expected type integer
--           in column "rank" (position N)
--
-- The Dart repository swallows exceptions (DemoRepository.getRegionCoverage /
-- getTargetCoverage / getFailureAnalysis all return const [] on catch),
-- so this would have surfaced as silently empty reports in the UI once
-- Fase 4 plugged the RPCs in. Caught by supabase/tests/prayer_reports_rpcs_smoke.sql.
--
-- Fix: cast `dense_rank()` to int. We could instead change RETURNS TABLE
-- to bigint, but the Dart models (RegionCoverageModel, TargetCoverageModel,
-- FailureAnalysisModel) all do `data['rank'] as int`, so casting in SQL is
-- the smaller surface.

begin;

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
        dense_rank() over (order by a.completed_runs desc, a.total_runs desc)::int as rank
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

create or replace function public.get_coverage_by_target(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date)
)
returns table (
  target_id uuid,
  target_name text,
  target_emoji text,
  total_runs integer,
  completed_runs integer,
  missed_runs integer,
  coverage_percentage double precision,
  unique_users integer,
  rank integer,
  responsible_users_json jsonb
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
    base as (
      select
        s.prayer_target_id as target_id,
        r.assigned_user_id as user_id,
        r.status
      from public.community_prayer_schedule_runs r
      join public.community_prayer_schedules s on s.id = r.schedule_id
      where r.community_id = p_community_id
        and (r.starts_at at time zone 'utc')::date between p_from and p_to
    ),
    agg as (
      select
        b.target_id,
        count(*)::int as total_runs,
        count(*) filter (where b.status = 'completed')::int as completed_runs,
        count(*) filter (where b.status = 'missed')::int as missed_runs,
        count(distinct b.user_id)::int as unique_users
      from base b
      group by b.target_id
    ),
    responsible as (
      select
        x.target_id,
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'id', x.user_id,
              'name', x.user_name,
              'count', x.completed_count
            )
            order by x.completed_count desc, x.user_name asc
          ),
          '[]'::jsonb
        ) as responsible_users_json
      from (
        select
          b.target_id,
          b.user_id,
          coalesce(nullif(trim(pr.display_name), ''), nullif(trim(pr.username), ''), 'Usuário') as user_name,
          count(*) filter (where b.status = 'completed')::int as completed_count
        from base b
        left join public.profiles pr on pr.id = b.user_id
        group by b.target_id, b.user_id, user_name
      ) x
      group by x.target_id
    ),
    ranked as (
      select
        a.*,
        dense_rank() over (order by a.completed_runs desc, a.total_runs desc)::int as rank
      from agg a
    )
  select
    r.target_id,
    coalesce(nullif(trim(pt.title), ''), 'Sem alvo') as target_name,
    pt.icon_emoji as target_emoji,
    r.total_runs,
    r.completed_runs,
    r.missed_runs,
    coalesce(r.completed_runs::double precision / nullif(r.total_runs::double precision, 0), 0.0) * 100.0 as coverage_percentage,
    r.unique_users,
    r.rank,
    coalesce(resp.responsible_users_json, '[]'::jsonb) as responsible_users_json
  from ranked r
  left join public.prayer_targets pt on pt.id = r.target_id
  left join responsible resp on resp.target_id is not distinct from r.target_id
  order by r.rank asc, target_name asc;
end;
$$;

create or replace function public.get_failure_analysis(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date)
)
returns table (
  user_id uuid,
  user_name text,
  failed_count integer,
  assigned_count integer,
  failure_rate double precision,
  rank integer,
  uncovered_targets_json jsonb,
  uncovered_regions_json jsonb,
  uncovered_time_slots_json jsonb,
  last_failure_at timestamptz
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
        r.assigned_user_id as user_id,
        r.status,
        r.starts_at,
        s.prayer_target_id,
        coalesce(ps.location_id, upr.region_id) as region_id
      from public.community_prayer_schedule_runs r
      join public.community_prayer_schedules s on s.id = r.schedule_id
      left join public.prayer_sessions ps on ps.id = r.completed_session_id
      left join user_primary_region upr on upr.user_id = r.assigned_user_id
      where r.community_id = p_community_id
        and (r.starts_at at time zone 'utc')::date between p_from and p_to
    ),
    agg as (
      select
        b.user_id,
        count(*) filter (where b.status = 'missed')::int as failed_count,
        count(*)::int as assigned_count,
        max(b.starts_at) filter (where b.status = 'missed') as last_failure_at
      from base b
      group by b.user_id
      having count(*) filter (where b.status = 'missed') > 0
    ),
    uncovered_targets as (
      select
        x.user_id,
        coalesce(jsonb_agg(x.target_name order by x.target_name), '[]'::jsonb) as uncovered_targets_json
      from (
        select distinct
          b.user_id,
          coalesce(nullif(trim(pt.title), ''), 'Sem alvo') as target_name
        from base b
        left join public.prayer_targets pt on pt.id = b.prayer_target_id
        where b.status = 'missed'
      ) x
      group by x.user_id
    ),
    uncovered_regions as (
      select
        x.user_id,
        coalesce(jsonb_agg(x.region_name order by x.region_name), '[]'::jsonb) as uncovered_regions_json
      from (
        select distinct
          b.user_id,
          coalesce(l.name, 'Desconhecida') as region_name
        from base b
        left join public.locations l on l.id = b.region_id
        where b.status = 'missed'
          and b.region_id is not null
      ) x
      group by x.user_id
    ),
    uncovered_slots as (
      select
        x.user_id,
        coalesce(jsonb_agg(x.hour_label order by x.hour_label), '[]'::jsonb) as uncovered_time_slots_json
      from (
        select distinct
          b.user_id,
          lpad(extract(hour from (b.starts_at at time zone 'utc'))::int::text, 2, '0') || ':00' as hour_label
        from base b
        where b.status = 'missed'
      ) x
      group by x.user_id
    ),
    ranked as (
      select
        a.*,
        dense_rank() over (order by a.failed_count desc, a.assigned_count desc)::int as rank
      from agg a
    )
  select
    r.user_id,
    coalesce(nullif(trim(pr.display_name), ''), nullif(trim(pr.username), ''), 'Usuário') as user_name,
    r.failed_count,
    r.assigned_count,
    coalesce(r.failed_count::double precision / nullif(r.assigned_count::double precision, 0), 0.0) * 100.0 as failure_rate,
    r.rank,
    coalesce(ut.uncovered_targets_json, '[]'::jsonb) as uncovered_targets_json,
    coalesce(ur.uncovered_regions_json, '[]'::jsonb) as uncovered_regions_json,
    coalesce(us.uncovered_time_slots_json, '[]'::jsonb) as uncovered_time_slots_json,
    r.last_failure_at
  from ranked r
  left join public.profiles pr on pr.id = r.user_id
  left join uncovered_targets ut on ut.user_id = r.user_id
  left join uncovered_regions ur on ur.user_id = r.user_id
  left join uncovered_slots us on us.user_id = r.user_id
  order by r.rank asc, user_name asc;
end;
$$;

commit;
