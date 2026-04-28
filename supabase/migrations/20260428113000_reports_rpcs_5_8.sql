begin;

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
        dense_rank() over (order by a.completed_runs desc, a.total_runs desc) as rank
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

create or replace function public.get_time_slot_coverage(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date),
  p_slot_minutes integer default 60
)
returns table (
  time_slot text,
  hour_start integer,
  hour_end integer,
  scheduled_count integer,
  completed_count integer,
  missed_count integer,
  empty_count integer,
  fill_percentage double precision,
  period_name text
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_slot integer := greatest(coalesce(p_slot_minutes, 60), 15);
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
    runs as (
      select
        r.status,
        extract(hour from (r.starts_at at time zone 'utc'))::int as hour_int
      from public.community_prayer_schedule_runs r
      where r.community_id = p_community_id
        and (r.starts_at at time zone 'utc')::date between p_from and p_to
    ),
    slot_agg as (
      select
        floor((hour_int * 60)::numeric / v_slot)::int as slot_index,
        count(*)::int as scheduled_count,
        count(*) filter (where status = 'completed')::int as completed_count,
        count(*) filter (where status = 'missed')::int as missed_count
      from runs
      group by floor((hour_int * 60)::numeric / v_slot)::int
    ),
    slots as (
      select generate_series(0, ceil((24 * 60)::numeric / v_slot)::int - 1) as slot_index
    )
  select
    lpad((least((s.slot_index * v_slot), (24 * 60)) / 60)::int::text, 2, '0')
      || ':' ||
      lpad((least((s.slot_index * v_slot), (24 * 60)) % 60)::int::text, 2, '0')
      || '-' ||
      lpad((least(((s.slot_index + 1) * v_slot), (24 * 60)) / 60)::int::text, 2, '0')
      || ':' ||
      lpad((least(((s.slot_index + 1) * v_slot), (24 * 60)) % 60)::int::text, 2, '0') as time_slot,
    (least((s.slot_index * v_slot), (24 * 60)) / 60)::int as hour_start,
    (least(((s.slot_index + 1) * v_slot), (24 * 60)) / 60)::int as hour_end,
    coalesce(a.scheduled_count, 0) as scheduled_count,
    coalesce(a.completed_count, 0) as completed_count,
    coalesce(a.missed_count, 0) as missed_count,
    case when coalesce(a.scheduled_count, 0) = 0 then 1 else 0 end as empty_count,
    coalesce(coalesce(a.completed_count, 0)::double precision / nullif(coalesce(a.scheduled_count, 0)::double precision, 0), 0.0) * 100.0 as fill_percentage,
    case
      when ((s.slot_index * v_slot) / 60)::int between 0 and 5 then 'Madrugada'
      when ((s.slot_index * v_slot) / 60)::int between 6 and 11 then 'Manhã'
      when ((s.slot_index * v_slot) / 60)::int between 12 and 17 then 'Tarde'
      else 'Noite'
    end as period_name
  from slots s
  left join slot_agg a on a.slot_index = s.slot_index
  order by s.slot_index asc;
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
        dense_rank() over (order by a.failed_count desc, a.assigned_count desc) as rank
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

create or replace function public.get_prayer_report_cross_data(
  p_community_id uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_user_ids uuid[] default null,
  p_target_ids uuid[] default null,
  p_region_ids uuid[] default null,
  p_statuses text[] default null,
  p_weekdays integer[] default null,
  p_hour_start integer default 0,
  p_hour_end integer default 23,
  p_limit integer default 200,
  p_offset integer default 0
)
returns table (
  run_id uuid,
  user_id uuid,
  user_name text,
  target_id uuid,
  target_name text,
  region_id uuid,
  region_name text,
  scheduled_at timestamptz,
  actual_at timestamptz,
  status text,
  duration_seconds integer,
  notes text
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hour_start int := greatest(coalesce(p_hour_start, 0), 0);
  v_hour_end int := least(coalesce(p_hour_end, 23), 23);
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
  if v_hour_end < v_hour_start then
    raise exception 'invalid_hour_range';
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
            and ps.started_at >= p_from
            and ps.started_at <= p_to
          group by ps.user_id, ps.location_id
        ) g
      ) x
      where x.rn = 1
    )
  select
    r.id as run_id,
    r.assigned_user_id as user_id,
    coalesce(nullif(trim(pr.display_name), ''), nullif(trim(pr.username), ''), 'Usuário') as user_name,
    s.prayer_target_id as target_id,
    coalesce(nullif(trim(pt.title), ''), 'Sem alvo') as target_name,
    coalesce(ps.location_id, upr.region_id) as region_id,
    coalesce(l.name, 'Desconhecida') as region_name,
    r.starts_at as scheduled_at,
    ps.started_at as actual_at,
    r.status,
    ps.duration_seconds,
    coalesce(
      nullif(trim(ps.notes), ''),
      nullif(trim(ps.observations), ''),
      nullif(trim(ps.revelations), ''),
      nullif(trim(r.notes), '')
    ) as notes
  from public.community_prayer_schedule_runs r
  join public.community_prayer_schedules s on s.id = r.schedule_id
  left join public.prayer_targets pt on pt.id = s.prayer_target_id
  left join public.prayer_sessions ps on ps.id = r.completed_session_id
  left join user_primary_region upr on upr.user_id = r.assigned_user_id
  left join public.locations l on l.id = coalesce(ps.location_id, upr.region_id)
  left join public.profiles pr on pr.id = r.assigned_user_id
  where r.community_id = p_community_id
    and r.starts_at >= p_from
    and r.starts_at <= p_to
    and (p_user_ids is null or r.assigned_user_id = any(p_user_ids))
    and (p_target_ids is null or s.prayer_target_id = any(p_target_ids))
    and (p_region_ids is null or coalesce(ps.location_id, upr.region_id) = any(p_region_ids))
    and (p_statuses is null or r.status = any(p_statuses))
    and (p_weekdays is null or extract(dow from (r.starts_at at time zone 'utc'))::int = any(p_weekdays))
    and extract(hour from (r.starts_at at time zone 'utc'))::int between v_hour_start and v_hour_end
  order by r.starts_at desc
  limit greatest(coalesce(p_limit, 200), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.get_coverage_by_target(uuid, date, date) from public;
grant execute on function public.get_coverage_by_target(uuid, date, date) to authenticated;

revoke all on function public.get_time_slot_coverage(uuid, date, date, integer) from public;
grant execute on function public.get_time_slot_coverage(uuid, date, date, integer) to authenticated;

revoke all on function public.get_failure_analysis(uuid, date, date) from public;
grant execute on function public.get_failure_analysis(uuid, date, date) to authenticated;

revoke all on function public.get_prayer_report_cross_data(uuid, timestamptz, timestamptz, uuid[], uuid[], uuid[], text[], integer[], integer, integer, integer, integer) from public;
grant execute on function public.get_prayer_report_cross_data(uuid, timestamptz, timestamptz, uuid[], uuid[], uuid[], text[], integer[], integer, integer, integer, integer) to authenticated;

commit;
