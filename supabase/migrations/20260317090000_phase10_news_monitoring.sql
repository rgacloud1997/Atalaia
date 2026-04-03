begin;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'news_source_kind') then
    create type public.news_source_kind as enum ('rss');
  end if;
  if not exists (select 1 from pg_type where typname = 'news_event_status') then
    create type public.news_event_status as enum ('open', 'resolved');
  end if;

  if not exists (select 1 from pg_type where typname = 'ai_urgency_level') then
    create type public.ai_urgency_level as enum ('low', 'medium', 'high', 'critical');
  end if;

  if not exists (select 1 from pg_type where typname = 'ai_category') then
    create type public.ai_category as enum (
      'health',
      'family',
      'finance',
      'relationships',
      'deliverance',
      'mental_health',
      'protection',
      'guidance',
      'gratitude',
      'other'
    );
  end if;
end;
$$;

create table if not exists public.news_sources (
  id uuid primary key default gen_random_uuid(),
  kind public.news_source_kind not null default 'rss'::public.news_source_kind,
  name text not null,
  url text not null,
  language text,
  region_hint_path text,
  is_active boolean not null default true,
  etag text,
  last_modified text,
  last_polled_at timestamptz,
  last_success_at timestamptz,
  last_error text,
  error_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists news_sources_url_unique on public.news_sources (url);
create index if not exists idx_news_sources_is_active on public.news_sources (is_active);

drop trigger if exists trg_news_sources_updated_at on public.news_sources;
create trigger trg_news_sources_updated_at
before update on public.news_sources
for each row execute function public.set_updated_at();

alter table public.news_sources enable row level security;

drop policy if exists "news_sources_select_active" on public.news_sources;
drop policy if exists "news_sources_write_service_only" on public.news_sources;

create policy "news_sources_select_active"
on public.news_sources for select
using (is_active = true);

create policy "news_sources_write_service_only"
on public.news_sources for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create table if not exists public.news_items (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.news_sources(id) on delete cascade,
  external_id text,
  url text,
  title text not null,
  summary text,
  content text,
  author text,
  published_at timestamptz,
  fetched_at timestamptz not null default now(),
  content_hash text not null,
  language text,
  lat double precision,
  lng double precision,
  location_id uuid references public.locations(id) on delete set null,
  processed_at timestamptz,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists news_items_content_hash_unique on public.news_items (content_hash);
create index if not exists idx_news_items_source_published_at on public.news_items (source_id, published_at desc);
create index if not exists idx_news_items_location_published_at on public.news_items (location_id, published_at desc);
create index if not exists idx_news_items_processed_at on public.news_items (processed_at);

alter table public.news_items enable row level security;

drop policy if exists "news_items_select_all" on public.news_items;
drop policy if exists "news_items_write_service_only" on public.news_items;

create policy "news_items_select_all"
on public.news_items for select
using (true);

create policy "news_items_write_service_only"
on public.news_items for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create table if not exists public.news_events (
  id uuid primary key default gen_random_uuid(),
  event_key text not null,
  status public.news_event_status not null default 'open'::public.news_event_status,
  title text not null,
  summary text,
  category public.ai_category not null default 'other'::public.ai_category,
  urgency_level public.ai_urgency_level not null default 'low'::public.ai_urgency_level,
  occurred_at timestamptz,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  location_id uuid references public.locations(id) on delete set null,
  location_path text,
  location_name text,
  lat double precision,
  lng double precision,
  prayer_post_id uuid references public.posts(id) on delete set null,
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists news_events_event_key_unique on public.news_events (event_key);
create index if not exists idx_news_events_status_last_seen_at on public.news_events (status, last_seen_at desc);
create index if not exists idx_news_events_location_id_last_seen_at on public.news_events (location_id, last_seen_at desc);

drop trigger if exists trg_news_events_updated_at on public.news_events;
create trigger trg_news_events_updated_at
before update on public.news_events
for each row execute function public.set_updated_at();

alter table public.news_events enable row level security;

drop policy if exists "news_events_select_open" on public.news_events;
drop policy if exists "news_events_write_service_only" on public.news_events;

create policy "news_events_select_open"
on public.news_events for select
using (status = 'open'::public.news_event_status);

create policy "news_events_write_service_only"
on public.news_events for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create table if not exists public.news_event_items (
  event_id uuid not null references public.news_events(id) on delete cascade,
  item_id uuid not null references public.news_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, item_id)
);

create index if not exists idx_news_event_items_item_id on public.news_event_items (item_id);

alter table public.news_event_items enable row level security;

drop policy if exists "news_event_items_select_open_event" on public.news_event_items;
drop policy if exists "news_event_items_write_service_only" on public.news_event_items;

create policy "news_event_items_select_open_event"
on public.news_event_items for select
using (
  exists (
    select 1
    from public.news_events e
    where e.id = news_event_items.event_id
      and e.status = 'open'::public.news_event_status
  )
);

create policy "news_event_items_write_service_only"
on public.news_event_items for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create or replace function public.news_system_actor_id()
returns uuid
language plpgsql
stable
set search_path = public
as $$
declare
  v uuid;
begin
  v := null;
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'system_moderator_id'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'select public.system_moderator_id()' into v;
  end if;

  if v is not null then
    return v;
  end if;

  if to_regclass('public.profiles') is not null then
    execute 'select p.id from public.profiles p order by p.created_at asc limit 1' into v;
  end if;

  return v;
end;
$$;

create or replace function public.news_process_items(p_limit integer default 200)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_loc record;
  v_cat public.ai_category;
  v_urg public.ai_urgency_level;
  v_event_id uuid;
  v_rows integer := 0;
  v_title text;
  v_summary text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service_role_required';
  end if;

  for r in
    select *
    from public.news_items i
    where i.processed_at is null
    order by coalesce(i.published_at, i.fetched_at) desc
    limit greatest(coalesce(p_limit, 200), 1)
  loop
    v_title := nullif(trim(coalesce(r.title, '')), '');
    if v_title is null then
      update public.news_items set processed_at = now() where id = r.id;
      continue;
    end if;
    v_summary := nullif(trim(coalesce(r.summary, r.content, '')), '');

    v_loc := null;
    if r.location_id is not null then
      select l.id as location_id, l.path, l.name, l.center_lat, l.center_lng
      into v_loc
      from public.locations l
      where l.id = r.location_id
      limit 1;
    elsif r.lat is not null and r.lng is not null then
      select location_id, path, name into v_loc
      from public.resolve_location_by_point_geom('city'::public.location_level, r.lat, r.lng)
      limit 1;
      if v_loc.location_id is null then
        select location_id, path, name into v_loc
        from public.resolve_location_by_point_geom('state'::public.location_level, r.lat, r.lng)
        limit 1;
      end if;
      if v_loc.location_id is null then
        select location_id, path, name into v_loc
        from public.resolve_location_by_point_geom('country'::public.location_level, r.lat, r.lng)
        limit 1;
      end if;
      if v_loc.location_id is not null then
        update public.news_items
        set location_id = v_loc.location_id
        where id = r.id;
      end if;
    end if;

    v_cat := 'other'::public.ai_category;
    v_urg := 'low'::public.ai_urgency_level;
    if exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'ai_classify_prayer_text'
    ) then
      execute 'select category, urgency_level from public.ai_classify_prayer_text($1) limit 1'
      into v_cat, v_urg
      using trim(v_title || ' ' || coalesce(v_summary, ''));
    end if;

    insert into public.news_events (
      event_key,
      status,
      title,
      summary,
      category,
      urgency_level,
      occurred_at,
      first_seen_at,
      last_seen_at,
      location_id,
      location_path,
      location_name,
      lat,
      lng
    )
    values (
      r.content_hash,
      'open'::public.news_event_status,
      v_title,
      v_summary,
      coalesce(v_cat, 'other'::public.ai_category),
      coalesce(v_urg, 'low'::public.ai_urgency_level),
      r.published_at,
      now(),
      now(),
      v_loc.location_id,
      v_loc.path,
      v_loc.name,
      coalesce(r.lat, v_loc.center_lat),
      coalesce(r.lng, v_loc.center_lng)
    )
    on conflict (event_key)
    do update set
      last_seen_at = now(),
      title = excluded.title,
      summary = excluded.summary,
      category = excluded.category,
      urgency_level = excluded.urgency_level,
      occurred_at = coalesce(excluded.occurred_at, public.news_events.occurred_at),
      location_id = coalesce(excluded.location_id, public.news_events.location_id),
      location_path = coalesce(excluded.location_path, public.news_events.location_path),
      location_name = coalesce(excluded.location_name, public.news_events.location_name),
      lat = coalesce(excluded.lat, public.news_events.lat),
      lng = coalesce(excluded.lng, public.news_events.lng)
    returning id into v_event_id;

    insert into public.news_event_items (event_id, item_id)
    values (v_event_id, r.id)
    on conflict do nothing;

    update public.news_items
    set processed_at = now()
    where id = r.id;

    v_rows := v_rows + 1;
  end loop;

  return v_rows;
end;
$$;

create or replace function public.news_materialize_prayers(p_limit integer default 50)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_actor uuid;
  v_post_id uuid;
  v_rows integer := 0;
  v_body text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service_role_required';
  end if;

  v_actor := public.news_system_actor_id();
  if v_actor is null then
    return 0;
  end if;

  for r in
    select e.*
    from public.news_events e
    where e.status = 'open'::public.news_event_status
      and e.prayer_post_id is null
      and e.last_seen_at > now() - interval '72 hours'
    order by
      case e.urgency_level
        when 'critical'::public.ai_urgency_level then 4
        when 'high'::public.ai_urgency_level then 3
        when 'medium'::public.ai_urgency_level then 2
        else 1
      end desc,
      e.last_seen_at desc
    limit greatest(coalesce(p_limit, 50), 1)
  loop
    v_body := trim(
      'Notícia: ' || r.title ||
      case when nullif(trim(coalesce(r.summary, '')), '') is null then '' else E'\n\n' || r.summary end ||
      case when nullif(trim(coalesce(r.location_name, '')), '') is null then '' else E'\n\nRegião: ' || r.location_name end ||
      E'\n\nVamos orar por essa situação.'
    );

    insert into public.posts (
      user_id,
      kind,
      post_type,
      visibility,
      body,
      tags,
      location_id,
      lat,
      lng
    )
    values (
      v_actor,
      'request'::public.post_kind,
      'prayer'::public.post_type,
      'public'::public.post_visibility,
      v_body,
      array['news','event']::text[],
      r.location_id,
      r.lat,
      r.lng
    )
    returning id into v_post_id;

    update public.news_events
    set prayer_post_id = v_post_id
    where id = r.id;

    v_rows := v_rows + 1;
  end loop;

  return v_rows;
end;
$$;

create or replace function public.news_notify_recent_events(p_limit integer default 200)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_actor uuid;
  v_rows integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service_role_required';
  end if;

  v_actor := public.news_system_actor_id();
  if v_actor is null then
    return 0;
  end if;

  for r in
    select e.id, e.title, e.location_id, e.location_path, e.notified_at
    from public.news_events e
    where e.status = 'open'::public.news_event_status
      and e.prayer_post_id is not null
      and e.notified_at is null
      and e.last_seen_at > now() - interval '72 hours'
    order by e.last_seen_at desc
    limit greatest(coalesce(p_limit, 200), 1)
  loop
    perform public.insert_notification_smart(
      p_user_id := rp.user_id,
      p_actor_id := v_actor,
      p_type := 'prayer_request',
      p_title := 'Notícia — Pedido de oração',
      p_body := r.title,
      p_entity_id := r.id,
      p_entity_type := 'news_event',
      p_location_id := r.location_id,
      p_is_community := false,
      p_bypass_scope := (r.location_id is null),
      p_is_alert := false
    )
    from public.region_prayers rp
    join public.locations sub on sub.id = rp.location_id
    left join public.locations ev on ev.id = r.location_id
    where (
      r.location_path is not null
      and sub.path is not null
      and (r.location_path = sub.path or r.location_path like (sub.path || '/%'))
    )
    or (
      r.location_path is null
      and r.location_id is not null
      and ev.path is not null
      and sub.path is not null
      and (ev.path = sub.path or ev.path like (sub.path || '/%'))
    );

    update public.news_events
    set notified_at = now()
    where id = r.id;

    v_rows := v_rows + 1;
  end loop;

  return v_rows;
end;
$$;

create or replace function public.feed_news_events_by_location(
  p_location_id uuid,
  p_cursor_last_seen_at timestamptz default null,
  p_limit integer default 24
)
returns table (
  id uuid,
  title text,
  summary text,
  category public.ai_category,
  urgency_level public.ai_urgency_level,
  occurred_at timestamptz,
  last_seen_at timestamptz,
  location_id uuid,
  location_path text,
  location_name text,
  prayer_post_id uuid,
  items_count bigint
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
    e.id,
    e.title,
    e.summary,
    e.category,
    e.urgency_level,
    e.occurred_at,
    e.last_seen_at,
    e.location_id,
    coalesce(e.location_path, l.path) as location_path,
    coalesce(e.location_name, l.name) as location_name,
    e.prayer_post_id,
    (select count(*) from public.news_event_items ei where ei.event_id = e.id) as items_count
  from public.news_events e
  left join public.locations l on l.id = e.location_id
  join target t on true
  where e.status = 'open'::public.news_event_status
    and t.path is not null
    and (
      e.location_path = t.path
      or e.location_path like (t.path || '/%')
      or (e.location_path is null and l.path is not null and (l.path = t.path or l.path like (t.path || '/%')))
    )
    and (
      p_cursor_last_seen_at is null
      or e.last_seen_at < p_cursor_last_seen_at
    )
  order by
    case e.urgency_level
      when 'critical'::public.ai_urgency_level then 4
      when 'high'::public.ai_urgency_level then 3
      when 'medium'::public.ai_urgency_level then 2
      else 1
    end desc,
    e.last_seen_at desc
  limit greatest(coalesce(p_limit, 24), 1);
$$;

grant execute on function public.feed_news_events_by_location(uuid, timestamptz, integer) to anon, authenticated;

create or replace function public.map_news_events_aggregate(
  p_level public.location_level,
  p_parent_id uuid default null,
  p_limit integer default 200
)
returns table (
  location_id uuid,
  events_count bigint,
  max_urgency public.ai_urgency_level
)
language sql
stable
set search_path = public
as $$
  with base as (
    select l.id, l.path
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
      count(e.id) as events_count,
      max(
        case e.urgency_level
          when 'critical'::public.ai_urgency_level then 4
          when 'high'::public.ai_urgency_level then 3
          when 'medium'::public.ai_urgency_level then 2
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
    left join public.news_events e
      on e.status = 'open'::public.news_event_status
     and e.location_id = ploc.id
     and e.last_seen_at > now() - interval '72 hours'
    group by b.id
  )
  select
    r.location_id,
    r.events_count,
    case r.max_weight
      when 4 then 'critical'::public.ai_urgency_level
      when 3 then 'high'::public.ai_urgency_level
      when 2 then 'medium'::public.ai_urgency_level
      else 'low'::public.ai_urgency_level
    end as max_urgency
  from rolled r
  where r.events_count > 0
  order by r.events_count desc
  limit greatest(coalesce(p_limit, 200), 1);
$$;

grant execute on function public.map_news_events_aggregate(public.location_level, uuid, integer) to anon, authenticated;

create or replace function public.news_event_detail(p_event_id uuid)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'event',
    to_jsonb(e),
    'items',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', i.id,
            'title', i.title,
            'url', i.url,
            'published_at', i.published_at,
            'source_id', i.source_id
          )
          order by coalesce(i.published_at, i.fetched_at) desc
        )
        from public.news_event_items ei
        join public.news_items i on i.id = ei.item_id
        where ei.event_id = e.id
        limit 12
      ),
      '[]'::jsonb
    )
  )
  from public.news_events e
  where e.id = p_event_id
  limit 1;
$$;

grant execute on function public.news_event_detail(uuid) to anon, authenticated;

revoke all on function public.news_process_items(integer) from public, anon, authenticated;
revoke all on function public.news_materialize_prayers(integer) from public, anon, authenticated;
revoke all on function public.news_notify_recent_events(integer) from public, anon, authenticated;
revoke all on function public.news_system_actor_id() from public, anon, authenticated;
revoke all on function public.news_event_detail(uuid) from public;
revoke all on function public.feed_news_events_by_location(uuid, timestamptz, integer) from public;
revoke all on function public.map_news_events_aggregate(public.location_level, uuid, integer) from public;

grant execute on function public.news_process_items(integer) to service_role;
grant execute on function public.news_materialize_prayers(integer) to service_role;
grant execute on function public.news_notify_recent_events(integer) to service_role;
grant execute on function public.news_system_actor_id() to service_role;

commit;

