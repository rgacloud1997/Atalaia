begin;

alter table if exists public.prayer_sessions
  add column if not exists prayer_record text,
  add column if not exists prayer_record_type text;

alter table public.prayer_sessions
  drop constraint if exists prayer_sessions_prayer_record_type_check;

alter table public.prayer_sessions
  add constraint prayer_sessions_prayer_record_type_check
  check (prayer_record_type is null or prayer_record_type in ('testimony', 'revelation', 'record', 'other')) not valid;

do $$
begin
  if exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'prayer_sessions'
      and c.column_name in ('notes', 'revelations', 'observations')
    group by c.table_schema, c.table_name
    having count(*) = 3
  ) then
    update public.prayer_sessions
    set prayer_record = coalesce(nullif(notes, ''), nullif(revelations, ''), nullif(observations, ''))
    where prayer_record is null
      and (
        coalesce(nullif(notes, ''), nullif(revelations, ''), nullif(observations, '')) is not null
      );
  end if;
end;
$$;

alter table if exists public.stories
  add column if not exists community_id uuid references public.communities(id) on delete cascade;

create index if not exists idx_stories_community_expires_at on public.stories (community_id, expires_at desc);

alter table public.stories enable row level security;

drop policy if exists "stories_select_active" on public.stories;
create policy "stories_select_active"
on public.stories for select
using (
  expires_at > now()
  and (
    community_id is null
    or (auth.uid() is not null and public.community_can_view(community_id, auth.uid()))
    or coalesce(auth.role(), '') = 'service_role'
  )
);

drop policy if exists "stories_insert_own" on public.stories;
create policy "stories_insert_own"
on public.stories for insert
with check (
  auth.uid() = user_id
  and (
    community_id is null
    or public.community_can_view(community_id, auth.uid())
    or coalesce(auth.role(), '') = 'service_role'
  )
);

drop policy if exists "stories_update_own" on public.stories;
create policy "stories_update_own"
on public.stories for update
using (
  auth.uid() = user_id
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  auth.uid() = user_id
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "stories_delete_own" on public.stories;
create policy "stories_delete_own"
on public.stories for delete
using (
  auth.uid() = user_id
  or coalesce(auth.role(), '') = 'service_role'
);

create or replace function public.create_community_prayer_weekly_schedule_and_runs(
  p_community_id uuid,
  p_title text,
  p_weekday integer,
  p_start_time time,
  p_duration_minutes integer,
  p_assigned_user_id uuid,
  p_weeks integer default 8,
  p_timezone text default 'UTC'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_schedule_id uuid;
  v_today date;
  v_today_dow integer;
  v_days_ahead integer;
  v_first_date date;
  v_first_starts_at timestamptz;
  v_i integer;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
begin
  if v_actor is null then
    raise exception 'auth_required';
  end if;
  if p_community_id is null then
    raise exception 'community_required';
  end if;
  if not public.community_is_admin(p_community_id, v_actor) then
    raise exception 'admin_required';
  end if;
  if p_weekday is null or p_weekday < 0 or p_weekday > 6 then
    raise exception 'weekday_invalid';
  end if;
  if p_start_time is null then
    raise exception 'start_time_required';
  end if;
  if p_duration_minutes is null or p_duration_minutes < 1 then
    raise exception 'duration_invalid';
  end if;
  if p_assigned_user_id is null then
    raise exception 'assigned_user_required';
  end if;

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
    coalesce(nullif(trim(p_title), ''), 'Escala de oração'),
    'weekly_fixed',
    coalesce(nullif(trim(p_timezone), ''), 'UTC'),
    p_weekday,
    p_start_time,
    p_duration_minutes,
    true,
    v_actor
  )
  returning id into v_schedule_id;

  v_today := (now() at time zone coalesce(nullif(trim(p_timezone), ''), 'UTC'))::date;
  v_today_dow := extract(dow from v_today)::int;
  v_days_ahead := (p_weekday - v_today_dow + 7) % 7;
  v_first_date := v_today + v_days_ahead;
  v_first_starts_at := make_timestamptz(
    extract(year from v_first_date)::int,
    extract(month from v_first_date)::int,
    extract(day from v_first_date)::int,
    extract(hour from p_start_time)::int,
    extract(minute from p_start_time)::int,
    0,
    coalesce(nullif(trim(p_timezone), ''), 'UTC')
  );
  if v_first_starts_at <= now() then
    v_first_date := v_first_date + 7;
    v_first_starts_at := v_first_starts_at + interval '7 days';
  end if;

  for v_i in 0..greatest(coalesce(p_weeks, 8), 1) - 1 loop
    v_starts_at := v_first_starts_at + (v_i * interval '7 days');
    v_ends_at := v_starts_at + make_interval(mins => p_duration_minutes);
    insert into public.community_prayer_schedule_runs (
      schedule_id,
      community_id,
      starts_at,
      ends_at,
      assigned_user_id,
      status,
      created_by
    )
    values (
      v_schedule_id,
      p_community_id,
      v_starts_at,
      v_ends_at,
      p_assigned_user_id,
      'scheduled',
      v_actor
    )
    on conflict do nothing;
  end loop;

  return v_schedule_id;
end;
$$;

revoke all on function public.create_community_prayer_weekly_schedule_and_runs(uuid, text, integer, time, integer, uuid, integer, text) from public;
grant execute on function public.create_community_prayer_weekly_schedule_and_runs(uuid, text, integer, time, integer, uuid, integer, text) to authenticated;

commit;
