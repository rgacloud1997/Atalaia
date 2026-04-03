begin;

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace where n.nspname = 'public' and t.typname = 'alert_category') then
    create type public.alert_category as enum (
      'prayer',
      'security',
      'health',
      'missing_person',
      'social_need',
      'traffic',
      'public_utility',
      'emergency'
    );
  end if;

  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace where n.nspname = 'public' and t.typname = 'alert_urgency') then
    create type public.alert_urgency as enum ('low', 'medium', 'high', 'critical');
  end if;

  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace where n.nspname = 'public' and t.typname = 'alert_status') then
    create type public.alert_status as enum ('active', 'monitoring', 'resolved', 'expired', 'archived');
  end if;

  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace where n.nspname = 'public' and t.typname = 'alert_media_type') then
    create type public.alert_media_type as enum ('none', 'image', 'video');
  end if;
end;
$$;

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  location_id uuid references public.locations(id) on delete set null,
  community_id uuid references public.communities(id) on delete set null,
  title text not null,
  description text not null,
  category public.alert_category not null,
  urgency public.alert_urgency not null default 'medium',
  status public.alert_status not null default 'active',
  media_url text,
  media_type public.alert_media_type not null default 'none',
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_alerts_location_created on public.alerts (location_id, created_at desc);
create index if not exists idx_alerts_community_created on public.alerts (community_id, created_at desc);
create index if not exists idx_alerts_status_expires on public.alerts (status, expires_at);
create index if not exists idx_alerts_urgency_created on public.alerts (urgency, created_at desc);

drop trigger if exists trg_alerts_updated_at on public.alerts;
create trigger trg_alerts_updated_at
before update on public.alerts
for each row execute function public.set_updated_at();

create or replace function public.expire_due_alerts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.alerts
  set status = 'expired'::public.alert_status
  where status in ('active'::public.alert_status, 'monitoring'::public.alert_status)
    and expires_at <= now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create table if not exists public.alert_follows (
  alert_id uuid not null references public.alerts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (alert_id, user_id)
);

create index if not exists idx_alert_follows_user on public.alert_follows (user_id);

alter table public.alerts enable row level security;
alter table public.alert_follows enable row level security;

drop policy if exists "alerts_select_visible" on public.alerts;
create policy "alerts_select_visible"
on public.alerts for select
using (
  (
    alerts.community_id is null
    or (
      auth.uid() is not null
      and (
        exists (
          select 1
          from public.communities c
          where c.id = alerts.community_id
            and c.owner_id = auth.uid()
        )
        or exists (
          select 1
          from public.community_members cm
          where cm.community_id = alerts.community_id
            and cm.user_id = auth.uid()
            and cm.status = 'active'
        )
      )
    )
  )
);

drop policy if exists "alerts_insert_own" on public.alerts;
create policy "alerts_insert_own"
on public.alerts for insert
with check (
  auth.uid() = user_id
  and (
    community_id is null
    or (
      exists (
        select 1
        from public.communities c
        where c.id = alerts.community_id
          and c.owner_id = auth.uid()
      )
      or exists (
        select 1
        from public.community_members cm
        where cm.community_id = alerts.community_id
          and cm.user_id = auth.uid()
          and cm.status = 'active'
      )
    )
  )
);

drop policy if exists "alerts_update_own_or_owner" on public.alerts;
create policy "alerts_update_own_or_owner"
on public.alerts for update
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.communities c
    where c.id = alerts.community_id
      and c.owner_id = auth.uid()
  )
)
with check (
  auth.uid() = user_id
  or exists (
    select 1
    from public.communities c
    where c.id = alerts.community_id
      and c.owner_id = auth.uid()
  )
);

drop policy if exists "alerts_delete_own_or_owner" on public.alerts;
create policy "alerts_delete_own_or_owner"
on public.alerts for delete
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.communities c
    where c.id = alerts.community_id
      and c.owner_id = auth.uid()
  )
);

drop policy if exists "alert_follows_select_own" on public.alert_follows;
create policy "alert_follows_select_own"
on public.alert_follows for select
using (auth.uid() = user_id);

drop policy if exists "alert_follows_insert_own" on public.alert_follows;
create policy "alert_follows_insert_own"
on public.alert_follows for insert
with check (auth.uid() = user_id);

drop policy if exists "alert_follows_delete_own" on public.alert_follows;
create policy "alert_follows_delete_own"
on public.alert_follows for delete
using (auth.uid() = user_id);

create or replace function public.map_alerts_aggregate(
  p_level public.location_level,
  p_parent_id uuid default null,
  p_community_id uuid default null,
  p_limit integer default 200
)
returns table (
  location_id uuid,
  location_path text,
  name text,
  level public.location_level,
  center_lat double precision,
  center_lng double precision,
  alerts_count bigint,
  max_urgency public.alert_urgency
)
language sql
stable
set search_path = public
as $$
  with base as (
    select
      l.id,
      l.path,
      l.name,
      l.level,
      l.center_lat,
      l.center_lng
    from public.locations l
    where l.level = p_level
      and (
        (p_parent_id is null and l.parent_id is null)
        or l.parent_id = p_parent_id
      )
  ),
  rolled as (
    select
      b.id as location_id,
      count(a.id) as alerts_count,
      max(
        case a.urgency
          when 'critical'::public.alert_urgency then 4
          when 'high'::public.alert_urgency then 3
          when 'medium'::public.alert_urgency then 2
          else 1
        end
      ) as max_weight
    from base b
    left join public.locations ploc
      on b.path is not null
     and ploc.path is not null
     and (
       ploc.path = b.path
       or ploc.path like (b.path || '/%')
     )
    left join public.alerts a
      on a.location_id = ploc.id
     and (p_community_id is null or a.community_id = p_community_id)
     and a.status in ('active'::public.alert_status, 'monitoring'::public.alert_status)
     and a.expires_at > now()
    group by b.id
  )
  select
    b.id as location_id,
    b.path as location_path,
    b.name,
    b.level,
    b.center_lat,
    b.center_lng,
    coalesce(r.alerts_count, 0) as alerts_count,
    case coalesce(r.max_weight, 0)
      when 4 then 'critical'::public.alert_urgency
      when 3 then 'high'::public.alert_urgency
      when 2 then 'medium'::public.alert_urgency
      when 1 then 'low'::public.alert_urgency
      else 'low'::public.alert_urgency
    end as max_urgency
  from base b
  left join rolled r on r.location_id = b.id
  order by alerts_count desc, b.name asc
  limit greatest(p_limit, 1);
$$;

create or replace function public.feed_alerts_by_location(
  p_location_id uuid,
  p_community_id uuid default null,
  p_cursor_created_at timestamptz default null,
  p_limit integer default 24
)
returns table (
  id uuid,
  user_id uuid,
  title text,
  description text,
  category public.alert_category,
  urgency public.alert_urgency,
  status public.alert_status,
  media_url text,
  media_type public.alert_media_type,
  expires_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  location_id uuid,
  location_path text,
  location_name text,
  community_id uuid
)
language sql
stable
set search_path = public
as $$
  with target as (
    select id, path
    from public.locations
    where id = p_location_id
    limit 1
  )
  select
    a.id,
    a.user_id,
    a.title,
    a.description,
    a.category,
    a.urgency,
    a.status,
    a.media_url,
    a.media_type,
    a.expires_at,
    a.created_at,
    a.updated_at,
    a.location_id,
    l.path as location_path,
    l.name as location_name,
    a.community_id
  from public.alerts a
  join public.locations l on l.id = a.location_id
  join target t on true
  where t.path is not null
    and (
      l.path = t.path
      or l.path like (t.path || '/%')
    )
    and (p_community_id is null or a.community_id = p_community_id)
    and a.status in ('active'::public.alert_status, 'monitoring'::public.alert_status)
    and a.expires_at > now()
    and (p_cursor_created_at is null or a.created_at < p_cursor_created_at)
  order by
    case a.urgency
      when 'critical'::public.alert_urgency then 4
      when 'high'::public.alert_urgency then 3
      when 'medium'::public.alert_urgency then 2
      else 1
    end desc,
    a.created_at desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.map_alerts_aggregate(public.location_level, uuid, uuid, integer) to anon, authenticated;
grant execute on function public.feed_alerts_by_location(uuid, uuid, timestamptz, integer) to anon, authenticated;

create or replace function public.trg_notify_on_alert_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
begin
  v_title := 'Novo alerta';
  v_body := nullif(trim(coalesce(new.title, '')), '');

  perform public.insert_notification_smart(
    p_user_id := r.recipient_id,
    p_actor_id := new.user_id,
    p_type := 'alert_new',
    p_title := v_title,
    p_body := v_body,
    p_entity_id := new.id,
    p_entity_type := 'alert',
    p_location_id := new.location_id,
    p_is_community := new.community_id is not null,
    p_bypass_scope := false,
    p_is_alert := true
  )
  from (
    select f.follower_id as recipient_id
    from public.follows f
    where f.following_id = new.user_id
    union
    select cm.user_id as recipient_id
    from public.community_members cm
    where new.community_id is not null
      and cm.community_id = new.community_id
      and cm.status = 'active'
  ) r
  where r.recipient_id is not null
    and r.recipient_id <> new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_alerts_notify on public.alerts;
create trigger trg_alerts_notify
after insert on public.alerts
for each row execute function public.trg_notify_on_alert_insert();

commit;
