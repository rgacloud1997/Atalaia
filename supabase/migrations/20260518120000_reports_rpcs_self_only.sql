-- Decisão de produto (18/05/2026): admin vê tudo da comunidade; membro
-- comum vê apenas os próprios dados. Sem este parâmetro, as 3 RPCs
-- exigiam `community_is_admin`, então membros não-admin não conseguiam
-- chamar nada e a UI da Fase 4 ficaria sem caminho para o usuário comum.
--
-- Adiciona `p_self_only boolean default false` nas 3 RPCs relevantes
-- (RPCs 1, 2 e 8). Quando true, exigimos apenas `community_can_view`
-- (membro ativo) e forçamos o filtro `assigned_user_id = auth.uid()` /
-- `ps.user_id = auth.uid()`. Default false mantém comportamento atual
-- (admin-only).
--
-- As outras RPCs (3, 4, 5, 6, 7) não recebem self_only — são agregadas
-- de comunidade que só fazem sentido para admin. Membros comuns enxergam
-- apenas o "resumo próprio" (RPC 1), "detalhe próprio" (RPC 2) e "drill
-- de runs próprias" (RPC 8).
--
-- Compatibilidade: default false preserva todos os callers atuais.

begin;

-- =====================================================================
-- RPC 1: get_prayer_scale_summary
-- =====================================================================

create or replace function public.get_prayer_scale_summary(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date),
  p_tz text default 'UTC',
  p_self_only boolean default false
)
returns table (
  total_scales integer,
  total_runs integer,
  total_completed integer,
  total_missed integer,
  total_cancelled integer,
  completion_rate double precision,
  unique_users integer,
  total_seconds bigint,
  total_minutes integer,
  avg_session_duration integer
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
  if p_self_only then
    if not public.community_can_view(p_community_id, v_uid) then
      raise exception 'not_allowed';
    end if;
  else
    if not public.community_is_admin(p_community_id, v_uid) then
      raise exception 'not_allowed';
    end if;
  end if;
  if p_from is null or p_to is null then
    raise exception 'range_required';
  end if;
  if p_to < p_from then
    raise exception 'invalid_range';
  end if;

  select
    count(*)::int as total_scales
  into
    total_scales
  from public.community_prayer_schedules s
  where s.community_id = p_community_id;

  select
    count(*)::int as total_runs,
    count(*) filter (where r.status = 'completed')::int as total_completed,
    count(*) filter (where r.status = 'missed')::int as total_missed,
    count(*) filter (where r.status = 'cancelled')::int as total_cancelled,
    count(distinct r.assigned_user_id)::int as unique_users
  into
    total_runs,
    total_completed,
    total_missed,
    total_cancelled,
    unique_users
  from public.community_prayer_schedule_runs r
  where r.community_id = p_community_id
    and (r.starts_at at time zone p_tz)::date between p_from and p_to
    and (not p_self_only or r.assigned_user_id = v_uid);

  select
    coalesce(sum(ps.duration_seconds), 0)::bigint as total_seconds,
    coalesce(round(avg(ps.duration_seconds) / 60.0), 0)::int as avg_session_duration
  into
    total_seconds,
    avg_session_duration
  from public.prayer_sessions ps
  where ps.community_id = p_community_id
    and ps.status = 'finished'
    and (ps.started_at at time zone p_tz)::date between p_from and p_to
    and (not p_self_only or ps.user_id = v_uid);

  total_minutes := floor(coalesce(total_seconds, 0) / 60.0)::int;

  completion_rate := coalesce(
    total_completed::double precision / nullif((total_completed + total_missed)::double precision, 0),
    0.0
  );

  return next;
end;
$$;

-- =====================================================================
-- RPC 2: get_prayer_by_user_detailed
-- =====================================================================

create or replace function public.get_prayer_by_user_detailed(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date),
  p_tz text default 'UTC',
  p_self_only boolean default false
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
  if p_self_only then
    if not public.community_can_view(p_community_id, v_uid) then
      raise exception 'not_allowed';
    end if;
  else
    if not public.community_is_admin(p_community_id, v_uid) then
      raise exception 'not_allowed';
    end if;
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
        and (r.starts_at at time zone p_tz)::date between p_from and p_to
        and (not p_self_only or r.assigned_user_id = v_uid)
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
              extract(hour from (r.starts_at at time zone p_tz))::int as hour_int,
              count(*)::int as cnt
            from runs_in_range r
            group by r.user_id, extract(hour from (r.starts_at at time zone p_tz))
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
            (r.starts_at at time zone p_tz)::date as day,
            ((r.starts_at at time zone p_tz)::date - row_number() over (
              partition by r.user_id
              order by (r.starts_at at time zone p_tz)::date
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

-- =====================================================================
-- RPC 8: get_prayer_report_cross_data
-- =====================================================================

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
  p_offset integer default 0,
  p_tz text default 'UTC',
  p_self_only boolean default false
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
  if p_self_only then
    if not public.community_can_view(p_community_id, v_uid) then
      raise exception 'not_allowed';
    end if;
  else
    if not public.community_is_admin(p_community_id, v_uid) then
      raise exception 'not_allowed';
    end if;
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
    and (not p_self_only or r.assigned_user_id = v_uid)
    and (p_user_ids is null or r.assigned_user_id = any(p_user_ids))
    and (p_target_ids is null or s.prayer_target_id = any(p_target_ids))
    and (p_region_ids is null or coalesce(ps.location_id, upr.region_id) = any(p_region_ids))
    and (p_statuses is null or r.status = any(p_statuses))
    and (p_weekdays is null or extract(dow from (r.starts_at at time zone p_tz))::int = any(p_weekdays))
    and extract(hour from (r.starts_at at time zone p_tz))::int between v_hour_start and v_hour_end
  order by r.starts_at desc
  limit greatest(coalesce(p_limit, 200), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- =====================================================================
-- GRANTS for new signatures
-- =====================================================================

revoke all on function public.get_prayer_scale_summary(uuid, date, date, text, boolean) from public;
grant execute on function public.get_prayer_scale_summary(uuid, date, date, text, boolean) to authenticated;

revoke all on function public.get_prayer_by_user_detailed(uuid, date, date, text, boolean) from public;
grant execute on function public.get_prayer_by_user_detailed(uuid, date, date, text, boolean) to authenticated;

revoke all on function public.get_prayer_report_cross_data(
  uuid, timestamptz, timestamptz,
  uuid[], uuid[], uuid[], text[], integer[],
  integer, integer, integer, integer, text, boolean
) from public;
grant execute on function public.get_prayer_report_cross_data(
  uuid, timestamptz, timestamptz,
  uuid[], uuid[], uuid[], text[], integer[],
  integer, integer, integer, integer, text, boolean
) to authenticated;

-- Drop the previous signatures (sem p_self_only) so callers must use the
-- new one. Defaults cobrem back-compat — callers que não passem p_self_only
-- continuam recebendo o comportamento admin-only.
drop function if exists public.get_prayer_scale_summary(uuid, date, date, text);
drop function if exists public.get_prayer_by_user_detailed(uuid, date, date, text);
drop function if exists public.get_prayer_report_cross_data(
  uuid, timestamptz, timestamptz,
  uuid[], uuid[], uuid[], text[], integer[],
  integer, integer, integer, integer, text
);

commit;
