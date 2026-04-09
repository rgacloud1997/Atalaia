begin;

create schema if not exists extensions;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'postgis') then
    begin
      alter extension postgis set schema extensions;
    exception
      when others then null;
    end;
  end if;
end;
$$;

do $$
declare
  r record;
begin
  for r in (
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'notifications_fill_kind'
  ) loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
end;
$$;

create or replace function public.ensure_notification_preferences(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null then
    return;
  end if;
  insert into public.notification_preferences (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;
end;
$$;

create or replace function public.insert_notification_smart(
  p_user_id uuid,
  p_actor_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_entity_id uuid,
  p_entity_type text,
  p_location_id uuid default null,
  p_is_community boolean default false,
  p_bypass_scope boolean default false,
  p_is_alert boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prefs public.notification_preferences%rowtype;
  v_level public.location_level;
  v_allow boolean;
  v_existing_id uuid;
  v_recent_count integer;
  v_kind public.notification_kind;
begin
  if p_user_id is null or p_type is null or p_type = '' then
    return;
  end if;
  if p_actor_id is not null and p_user_id = p_actor_id then
    return;
  end if;

  begin
    v_kind := p_type::public.notification_kind;
  exception
    when others then
      v_kind := null;
  end;

  perform public.ensure_notification_preferences(p_user_id);
  select * into v_prefs from public.notification_preferences where user_id = p_user_id;

  v_allow := true;

  if p_is_community and not v_prefs.community_enabled then
    v_allow := false;
  end if;

  if not p_bypass_scope and p_location_id is not null then
    select l.level into v_level
    from public.locations l
    where l.id = p_location_id
    limit 1;

    if v_level = 'world'::public.location_level and not v_prefs.world_enabled then
      v_allow := false;
    elsif v_level = 'country'::public.location_level and not v_prefs.country_enabled then
      v_allow := false;
    elsif v_level = 'state'::public.location_level and not v_prefs.state_enabled then
      v_allow := false;
    elsif v_level = 'city'::public.location_level and not v_prefs.city_enabled then
      v_allow := false;
    end if;
  end if;

  if p_type in ('post_new') and not v_prefs.posts_enabled then
    v_allow := false;
  end if;
  if p_type in ('story_new') and not v_prefs.stories_enabled then
    v_allow := false;
  end if;
  if p_type in ('prayer_request', 'prayed') and not v_prefs.prayers_enabled then
    v_allow := false;
  end if;
  if p_type in ('alert_new') and not v_prefs.alerts_enabled then
    v_allow := false;
  end if;
  if p_type in ('comment', 'reaction') and not v_prefs.posts_enabled then
    v_allow := false;
  end if;

  if not v_allow then
    return;
  end if;

  if not p_is_alert then
    select count(*)::int into v_recent_count
    from public.notifications n
    where n.user_id = p_user_id
      and n.type = p_type
      and n.created_at > now() - interval '10 minutes';
    if v_recent_count >= 6 then
      return;
    end if;
  end if;

  select n.id into v_existing_id
  from public.notifications n
  where n.user_id = p_user_id
    and n.is_read = false
    and n.type = p_type
    and n.entity_type is not distinct from p_entity_type
    and n.entity_id is not distinct from p_entity_id
    and n.created_at > now() - interval '2 hours'
  order by n.created_at desc
  limit 1;

  if v_existing_id is not null and not p_is_alert then
    update public.notifications
    set
      title = coalesce(p_title, title),
      body = coalesce(p_body, body),
      actor_id = coalesce(p_actor_id, actor_id),
      location_id = coalesce(p_location_id, location_id),
      kind = coalesce(kind, v_kind),
      created_at = now()
    where id = v_existing_id;
    return;
  end if;

  insert into public.notifications (
    user_id,
    actor_id,
    kind,
    type,
    title,
    body,
    entity_id,
    entity_type,
    location_id,
    is_read,
    created_at
  )
  values (
    p_user_id,
    p_actor_id,
    v_kind,
    p_type,
    p_title,
    p_body,
    p_entity_id,
    p_entity_type,
    p_location_id,
    false,
    now()
  );
end;
$$;

commit;

