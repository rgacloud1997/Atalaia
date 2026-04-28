begin;

create or replace function public.get_prayer_scale_summary(
  p_community_id uuid,
  p_from date default ((now() at time zone 'utc')::date - 29),
  p_to date default ((now() at time zone 'utc')::date)
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
    and (r.starts_at at time zone 'utc')::date between p_from and p_to;

  select
    coalesce(sum(ps.duration_seconds), 0)::bigint as total_seconds,
    coalesce(round(avg(ps.duration_seconds) / 60.0), 0)::int as avg_session_duration
  into
    total_seconds,
    avg_session_duration
  from public.prayer_sessions ps
  where ps.community_id = p_community_id
    and ps.status = 'finished'
    and (ps.started_at at time zone 'utc')::date between p_from and p_to;

  total_minutes := floor(coalesce(total_seconds, 0) / 60.0)::int;

  completion_rate := coalesce(
    total_completed::double precision / nullif((total_completed + total_missed)::double precision, 0),
    0.0
  );

  return next;
end;
$$;

revoke all on function public.get_prayer_scale_summary(uuid, date, date) from public;
grant execute on function public.get_prayer_scale_summary(uuid, date, date) to authenticated;

commit;
