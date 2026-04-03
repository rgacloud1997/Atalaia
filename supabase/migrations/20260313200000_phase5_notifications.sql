begin;

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  world_enabled boolean not null default true,
  country_enabled boolean not null default true,
  state_enabled boolean not null default true,
  city_enabled boolean not null default true,
  community_enabled boolean not null default true,
  alerts_enabled boolean not null default true,
  prayers_enabled boolean not null default true,
  stories_enabled boolean not null default true,
  posts_enabled boolean not null default true,
  push_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_notification_preferences_updated_at on public.notification_preferences;
create trigger trg_notification_preferences_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

alter table public.notification_preferences enable row level security;

drop policy if exists "notification_preferences_select_own" on public.notification_preferences;
drop policy if exists "notification_preferences_insert_own" on public.notification_preferences;
drop policy if exists "notification_preferences_update_own" on public.notification_preferences;

create policy "notification_preferences_select_own"
on public.notification_preferences for select
using (auth.uid() = user_id);

create policy "notification_preferences_insert_own"
on public.notification_preferences for insert
with check (auth.uid() = user_id);

create policy "notification_preferences_update_own"
on public.notification_preferences for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

alter table public.notifications
  add column if not exists type text,
  add column if not exists title text,
  add column if not exists body text,
  add column if not exists entity_id uuid,
  add column if not exists entity_type text,
  add column if not exists location_id uuid references public.locations(id) on delete set null,
  add column if not exists is_read boolean not null default false;

update public.notifications
set
  type = coalesce(type, kind::text),
  is_read = coalesce(is_read, read_at is not null),
  entity_id = coalesce(entity_id, entity_id),
  entity_type = coalesce(entity_type, 'post')
where type is null or is_read is null;

create index if not exists idx_notifications_user_id_is_read_created_at
on public.notifications (user_id, is_read, created_at desc);

create or replace function public.ensure_notification_preferences(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
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

insert into public.notification_preferences (user_id)
select p.id
from public.profiles p
on conflict (user_id) do nothing;

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
set search_path = public
as $$
declare
  v_prefs public.notification_preferences%rowtype;
  v_level public.location_level;
  v_allow boolean;
  v_existing_id uuid;
  v_recent_count integer;
begin
  if p_user_id is null or p_type is null or p_type = '' then
    return;
  end if;
  if p_actor_id is not null and p_user_id = p_actor_id then
    return;
  end if;

  perform public.ensure_notification_preferences(p_user_id);
  select * into v_prefs from public.notification_preferences where user_id = p_user_id;

  v_allow := true;

  if p_is_community and not v_prefs.community_enabled then
    v_allow := false;
  end if;

  if not p_bypass_scope and p_location_id is not null then
    select level into v_level
    from public.locations
    where id = p_location_id
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
      created_at = now()
    where id = v_existing_id;
    return;
  end if;

  insert into public.notifications (
    user_id,
    actor_id,
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
    when new.post_type = 'alert'::public.post_type then 'alert_new'
    when new.post_type = 'prayer'::public.post_type then 'prayer_request'
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

create or replace function public.trg_notify_on_story_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.insert_notification_smart(
    p_user_id := f.follower_id,
    p_actor_id := new.user_id,
    p_type := 'story_new',
    p_title := 'Novo story',
    p_body := null,
    p_entity_id := new.id,
    p_entity_type := 'story',
    p_location_id := new.city_id,
    p_is_community := false,
    p_bypass_scope := false,
    p_is_alert := false
  )
  from public.follows f
  where f.following_id = new.user_id
    and f.follower_id <> new.user_id;
  return new;
end;
$$;

create or replace function public.trg_notify_on_comment_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_location_id uuid;
  v_is_community boolean;
begin
  select p.user_id, p.location_id, (p.community_id is not null)
  into v_owner_id, v_location_id, v_is_community
  from public.posts p
  where p.id = new.post_id
  limit 1;

  if v_owner_id is null or v_owner_id = new.user_id then
    return new;
  end if;

  perform public.insert_notification_smart(
    p_user_id := v_owner_id,
    p_actor_id := new.user_id,
    p_type := 'comment',
    p_title := 'Novo comentário',
    p_body := left(new.body, 140),
    p_entity_id := new.post_id,
    p_entity_type := 'post',
    p_location_id := v_location_id,
    p_is_community := v_is_community,
    p_bypass_scope := true,
    p_is_alert := false
  );
  return new;
end;
$$;

create or replace function public.trg_notify_on_reaction_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_location_id uuid;
  v_is_community boolean;
begin
  select p.user_id, p.location_id, (p.community_id is not null)
  into v_owner_id, v_location_id, v_is_community
  from public.posts p
  where p.id = new.post_id
  limit 1;

  if v_owner_id is null or v_owner_id = new.user_id then
    return new;
  end if;

  perform public.insert_notification_smart(
    p_user_id := v_owner_id,
    p_actor_id := new.user_id,
    p_type := 'reaction',
    p_title := 'Curtida',
    p_body := null,
    p_entity_id := new.post_id,
    p_entity_type := 'post',
    p_location_id := v_location_id,
    p_is_community := v_is_community,
    p_bypass_scope := true,
    p_is_alert := false
  );
  return new;
end;
$$;

create or replace function public.trg_notify_on_prayer_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_location_id uuid;
  v_is_community boolean;
begin
  select p.user_id, p.location_id, (p.community_id is not null)
  into v_owner_id, v_location_id, v_is_community
  from public.posts p
  where p.id = new.post_id
  limit 1;

  if v_owner_id is null or v_owner_id = new.user_id then
    return new;
  end if;

  perform public.insert_notification_smart(
    p_user_id := v_owner_id,
    p_actor_id := new.user_id,
    p_type := 'prayed',
    p_title := 'Alguém orou por você',
    p_body := null,
    p_entity_id := new.post_id,
    p_entity_type := 'post',
    p_location_id := v_location_id,
    p_is_community := v_is_community,
    p_bypass_scope := true,
    p_is_alert := false
  );
  return new;
end;
$$;

create or replace function public.trg_notify_on_follow_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.insert_notification_smart(
    p_user_id := new.following_id,
    p_actor_id := new.follower_id,
    p_type := 'follow',
    p_title := 'Novo seguidor',
    p_body := null,
    p_entity_id := null,
    p_entity_type := 'user',
    p_location_id := null,
    p_is_community := false,
    p_bypass_scope := true,
    p_is_alert := false
  );
  return new;
end;
$$;

drop trigger if exists trg_posts_notify on public.posts;
create trigger trg_posts_notify
after insert on public.posts
for each row execute function public.trg_notify_on_post_insert();

do $$
begin
  if to_regclass('public.stories') is not null then
    execute 'drop trigger if exists trg_stories_notify on public.stories';
    execute 'create trigger trg_stories_notify after insert on public.stories for each row execute function public.trg_notify_on_story_insert()';
  end if;
end
$$;

drop trigger if exists trg_comments_notify on public.comments;
create trigger trg_comments_notify
after insert on public.comments
for each row execute function public.trg_notify_on_comment_insert();

drop trigger if exists trg_reactions_notify on public.reactions;
create trigger trg_reactions_notify
after insert on public.reactions
for each row execute function public.trg_notify_on_reaction_insert();

drop trigger if exists trg_prayers_notify on public.prayers;
create trigger trg_prayers_notify
after insert on public.prayers
for each row execute function public.trg_notify_on_prayer_insert();

drop trigger if exists trg_follows_notify on public.follows;
create trigger trg_follows_notify
after insert on public.follows
for each row execute function public.trg_notify_on_follow_insert();

commit;
