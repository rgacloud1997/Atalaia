begin;

create or replace function public.trg_notify_on_post_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
  v_title text;
  v_body text;
begin
  v_type := case
    when coalesce(new.post_type::text, '') = 'alert' then 'alert_new'
    when coalesce(new.post_type::text, '') = 'prayer' then 'prayer_request'
    else 'post_new'
  end;

  v_title := case
    when v_type = 'alert_new' then 'Novo alerta'
    when v_type = 'prayer_request' then 'Novo pedido de oração'
    else 'Novo post'
  end;

  v_body := nullif(trim(coalesce(new.body, '')), '');

  perform public.insert_notification_smart(
    p_user_id := r.recipient_id,
    p_actor_id := new.user_id,
    p_type := v_type,
    p_title := v_title,
    p_body := v_body,
    p_entity_id := new.id,
    p_entity_type := 'post',
    p_location_id := new.location_id,
    p_is_community := new.community_id is not null,
    p_bypass_scope := false,
    p_is_alert := (v_type = 'alert_new')
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
      'prayer',
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

commit;
