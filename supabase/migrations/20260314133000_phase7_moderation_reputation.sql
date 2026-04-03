begin;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'verification_type'
  ) then
    create type public.verification_type as enum (
      'none',
      'community_leader',
      'church',
      'organization',
      'moderator',
      'admin'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'reputation_level'
  ) then
    create type public.reputation_level as enum ('new', 'bronze', 'silver', 'gold', 'platinum');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'report_status'
  ) then
    create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
  end if;

  if exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'report_target_kind'
  ) then
    if not exists (
      select 1
      from pg_enum e
      join pg_type t on t.oid = e.enumtypid
      join pg_namespace n on n.oid = t.typnamespace
      where n.nspname = 'public' and t.typname = 'report_target_kind' and e.enumlabel = 'story'
    ) then
      alter type public.report_target_kind add value 'story';
    end if;

    if not exists (
      select 1
      from pg_enum e
      join pg_type t on t.oid = e.enumtypid
      join pg_namespace n on n.oid = t.typnamespace
      where n.nspname = 'public' and t.typname = 'report_target_kind' and e.enumlabel = 'alert'
    ) then
      alter type public.report_target_kind add value 'alert';
    end if;
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'moderation_action'
  ) then
    create type public.moderation_action as enum (
      'set_report_status',
      'remove_content',
      'warn_user',
      'suspend_user',
      'unsuspend_user',
      'adjust_reputation'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'alert_vote'
  ) then
    create type public.alert_vote as enum ('confirmed', 'false', 'resolved');
  end if;
end;
$$;

alter table public.profiles
  add column if not exists reputation_score integer not null default 0,
  add column if not exists reputation_level public.reputation_level not null default 'new',
  add column if not exists verification_type public.verification_type not null default 'none',
  add column if not exists suspended_until timestamptz,
  add column if not exists warnings_count integer not null default 0,
  add column if not exists strikes_count integer not null default 0;

alter table public.reports
  add column if not exists reported_user_id uuid references auth.users(id) on delete set null,
  add column if not exists resolved_by uuid references auth.users(id) on delete set null,
  add column if not exists resolved_at timestamptz;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'reports' and column_name = 'target_kind'
  ) then
    execute 'alter table public.reports rename column target_kind to entity_type';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'reports' and column_name = 'target_id'
  ) then
    execute 'alter table public.reports rename column target_id to entity_id';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'reports' and column_name = 'details'
  ) then
    execute 'alter table public.reports rename column details to description';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'reports' and column_name = 'status'
  ) then
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'reports' and column_name = 'status' and udt_name <> 'report_status'
    ) then
      execute $q$
        alter table public.reports
          alter column status drop default
      $q$;
      execute $q$
        alter table public.reports
          alter column status type public.report_status
          using (
            case lower(coalesce(status::text, 'open'))
              when 'open' then 'open'::public.report_status
              when 'reviewing' then 'reviewing'::public.report_status
              when 'resolved' then 'resolved'::public.report_status
              when 'dismissed' then 'dismissed'::public.report_status
              else 'open'::public.report_status
            end
          )
      $q$;
      execute $q$
        alter table public.reports
          alter column status set default 'open'::public.report_status
      $q$;
    end if;
  end if;
end;
$$;

create index if not exists idx_reports_reported_user_id on public.reports (reported_user_id);
create index if not exists idx_reports_status_created_at on public.reports (status, created_at desc);

create table if not exists public.moderation_logs (
  id uuid primary key default gen_random_uuid(),
  moderator_id uuid not null references auth.users(id) on delete restrict,
  action public.moderation_action not null,
  entity_type text,
  entity_id uuid,
  target_user_id uuid references auth.users(id) on delete set null,
  meta jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_moderation_logs_created_at on public.moderation_logs (created_at desc);
create index if not exists idx_moderation_logs_target_user on public.moderation_logs (target_user_id, created_at desc);

alter table public.moderation_logs enable row level security;

create or replace function public.is_moderator(p_user_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles pr
    where pr.id = p_user_id
      and pr.verification_type in ('moderator'::public.verification_type, 'admin'::public.verification_type)
  );
$$;

create or replace function public.reputation_level_for_score(p_score integer)
returns public.reputation_level
language sql
stable
set search_path = public
as $$
  select case
    when p_score >= 200 then 'platinum'::public.reputation_level
    when p_score >= 120 then 'gold'::public.reputation_level
    when p_score >= 60 then 'silver'::public.reputation_level
    when p_score >= 20 then 'bronze'::public.reputation_level
    else 'new'::public.reputation_level
  end;
$$;

create or replace function public.apply_reputation_delta(
  p_user_id uuid,
  p_delta integer,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null or p_delta is null or p_delta = 0 then
    return;
  end if;

  update public.profiles
  set
    reputation_score = greatest(coalesce(reputation_score, 0) + p_delta, -9999),
    reputation_level = public.reputation_level_for_score(greatest(coalesce(reputation_score, 0) + p_delta, -9999))
  where id = p_user_id;
end;
$$;

create or replace function public.system_moderator_id()
returns uuid
language sql
stable
set search_path = public
as $$
  select pr.id
  from public.profiles pr
  where pr.verification_type in ('admin'::public.verification_type, 'moderator'::public.verification_type)
  order by (pr.verification_type = 'admin'::public.verification_type) desc
  limit 1;
$$;

create or replace function public.reports_set_reported_user_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.reported_user_id is not null then
    return new;
  end if;

  if new.entity_type = 'user'::public.report_target_kind then
    new.reported_user_id = new.entity_id;
  elsif new.entity_type = 'post'::public.report_target_kind then
    select p.user_id into new.reported_user_id from public.posts p where p.id = new.entity_id;
  elsif new.entity_type = 'comment'::public.report_target_kind then
    select c.user_id into new.reported_user_id from public.comments c where c.id = new.entity_id;
  elsif new.entity_type = 'story'::public.report_target_kind then
    select s.user_id into new.reported_user_id from public.stories s where s.id = new.entity_id;
  elsif new.entity_type = 'alert'::public.report_target_kind then
    select a.user_id into new.reported_user_id from public.alerts a where a.id = new.entity_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_reports_set_reported_user_id on public.reports;
create trigger trg_reports_set_reported_user_id
before insert on public.reports
for each row execute function public.reports_set_reported_user_id();

create or replace function public.reports_auto_penalize()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
  v_until timestamptz;
  v_actor uuid;
begin
  if new.reported_user_id is null then
    return new;
  end if;

  select count(*) into v_count
  from public.reports r
  where r.reported_user_id = new.reported_user_id
    and r.status = 'open'::public.report_status
    and r.created_at > now() - interval '7 days';

  if v_count >= 5 then
    v_until := now() + interval '24 hours';
    update public.profiles
    set
      suspended_until = greatest(coalesce(suspended_until, now() - interval '100 years'), v_until),
      strikes_count = coalesce(strikes_count, 0) + 1
    where id = new.reported_user_id;

    perform public.apply_reputation_delta(new.reported_user_id, -20, 'auto_reports');

    v_actor := coalesce(public.system_moderator_id(), new.reporter_id);
    insert into public.moderation_logs (moderator_id, action, entity_type, entity_id, target_user_id, meta)
    values (
      v_actor,
      'suspend_user'::public.moderation_action,
      'user',
      new.reported_user_id,
      new.reported_user_id,
      jsonb_build_object('reason', 'auto_reports', 'reports_7d', v_count, 'until', v_until)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_reports_auto_penalize on public.reports;
create trigger trg_reports_auto_penalize
after insert on public.reports
for each row execute function public.reports_auto_penalize();

alter table public.alerts
  add column if not exists confidence_score double precision not null default 0.5;

create table if not exists public.alert_votes (
  alert_id uuid not null references public.alerts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  vote public.alert_vote not null,
  created_at timestamptz not null default now(),
  primary key (alert_id, user_id)
);

alter table public.alert_votes enable row level security;

drop policy if exists "alert_votes_select_own" on public.alert_votes;
create policy "alert_votes_select_own"
on public.alert_votes for select
using (auth.uid() = user_id);

drop policy if exists "alert_votes_upsert_own" on public.alert_votes;
create policy "alert_votes_upsert_own"
on public.alert_votes for insert
with check (auth.uid() = user_id);

drop policy if exists "alert_votes_update_own" on public.alert_votes;
create policy "alert_votes_update_own"
on public.alert_votes for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "alert_votes_delete_own" on public.alert_votes;
create policy "alert_votes_delete_own"
on public.alert_votes for delete
using (auth.uid() = user_id);

create or replace function public.recompute_alert_confidence(p_alert_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_confirmed integer;
  v_false integer;
  v_resolved integer;
  v_total integer;
  v_score double precision;
begin
  if p_alert_id is null then
    return;
  end if;

  select
    count(*) filter (where v.vote = 'confirmed'::public.alert_vote),
    count(*) filter (where v.vote = 'false'::public.alert_vote),
    count(*) filter (where v.vote = 'resolved'::public.alert_vote)
  into v_confirmed, v_false, v_resolved
  from public.alert_votes v
  where v.alert_id = p_alert_id;

  v_total := v_confirmed + v_false;

  if v_total <= 0 then
    v_score := 0.5;
  else
    v_score := greatest(0.0, least(1.0, 0.5 + ((v_confirmed - v_false)::double precision / (2.0 * v_total::double precision))));
  end if;

  update public.alerts
  set confidence_score = v_score
  where id = p_alert_id;

  if v_resolved >= 3 then
    update public.alerts
    set status = 'resolved'::public.alert_status
    where id = p_alert_id and status in ('active'::public.alert_status, 'monitoring'::public.alert_status);
  end if;
end;
$$;

create or replace function public.alert_votes_recompute_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recompute_alert_confidence(old.alert_id);
  else
    perform public.recompute_alert_confidence(new.alert_id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_alert_votes_recompute on public.alert_votes;
create trigger trg_alert_votes_recompute
after insert or update or delete on public.alert_votes
for each row execute function public.alert_votes_recompute_trigger();

create or replace function public.vote_on_alert(p_alert_id uuid, p_vote public.alert_vote)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;
  if p_alert_id is null then
    raise exception 'alert_id is required';
  end if;

  insert into public.alert_votes (alert_id, user_id, vote)
  values (p_alert_id, v_user_id, p_vote)
  on conflict (alert_id, user_id) do update set vote = excluded.vote, created_at = now();
end;
$$;

create or replace function public.moderation_set_report_status(
  p_report_id uuid,
  p_status public.report_status,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();
  if not public.is_moderator(v_actor) then
    raise exception 'not allowed';
  end if;

  update public.reports
  set
    status = p_status,
    resolved_by = case when p_status in ('resolved'::public.report_status, 'dismissed'::public.report_status) then v_actor else resolved_by end,
    resolved_at = case when p_status in ('resolved'::public.report_status, 'dismissed'::public.report_status) then now() else resolved_at end
  where id = p_report_id;

  insert into public.moderation_logs (moderator_id, action, entity_type, entity_id, meta, created_at)
  values (v_actor, 'set_report_status'::public.moderation_action, 'report', p_report_id, jsonb_build_object('status', p_status::text, 'note', p_note), now());
end;
$$;

create or replace function public.moderation_warn_user(
  p_user_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();
  if not public.is_moderator(v_actor) then
    raise exception 'not allowed';
  end if;

  update public.profiles
  set warnings_count = coalesce(warnings_count, 0) + 1
  where id = p_user_id;

  perform public.apply_reputation_delta(p_user_id, -8, 'warned');

  insert into public.moderation_logs (moderator_id, action, entity_type, entity_id, target_user_id, meta, created_at)
  values (v_actor, 'warn_user'::public.moderation_action, 'user', p_user_id, p_user_id, jsonb_build_object('note', p_note), now());
end;
$$;

create or replace function public.moderation_suspend_user(
  p_user_id uuid,
  p_seconds integer,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
  v_until timestamptz;
begin
  v_actor := auth.uid();
  if not public.is_moderator(v_actor) then
    raise exception 'not allowed';
  end if;
  if p_seconds is null or p_seconds <= 0 then
    raise exception 'invalid duration';
  end if;
  v_until := now() + make_interval(secs => p_seconds);

  update public.profiles
  set suspended_until = greatest(coalesce(suspended_until, now() - interval '100 years'), v_until)
  where id = p_user_id;

  perform public.apply_reputation_delta(p_user_id, -20, 'suspended');

  insert into public.moderation_logs (moderator_id, action, entity_type, entity_id, target_user_id, meta, created_at)
  values (
    v_actor,
    'suspend_user'::public.moderation_action,
    'user',
    p_user_id,
    p_user_id,
    jsonb_build_object('note', p_note, 'until', v_until, 'seconds', p_seconds),
    now()
  );
end;
$$;

create or replace function public.moderation_remove_content(
  p_entity_type public.report_target_kind,
  p_entity_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();
  if not public.is_moderator(v_actor) then
    raise exception 'not allowed';
  end if;

  if p_entity_type = 'post'::public.report_target_kind then
    delete from public.posts where id = p_entity_id;
  elsif p_entity_type = 'comment'::public.report_target_kind then
    delete from public.comments where id = p_entity_id;
  elsif p_entity_type = 'story'::public.report_target_kind then
    delete from public.stories where id = p_entity_id;
  elsif p_entity_type = 'alert'::public.report_target_kind then
    delete from public.alerts where id = p_entity_id;
  elsif p_entity_type = 'user'::public.report_target_kind then
    update public.profiles set suspended_until = now() + interval '365 days' where id = p_entity_id;
  end if;

  insert into public.moderation_logs (moderator_id, action, entity_type, entity_id, meta, created_at)
  values (
    v_actor,
    'remove_content'::public.moderation_action,
    p_entity_type::text,
    p_entity_id,
    jsonb_build_object('note', p_note),
    now()
  );
end;
$$;

drop policy if exists "reports_select_moderators" on public.reports;
create policy "reports_select_moderators"
on public.reports for select
using (public.is_moderator(auth.uid()));

drop policy if exists "reports_update_moderators" on public.reports;
create policy "reports_update_moderators"
on public.reports for update
using (public.is_moderator(auth.uid()))
with check (public.is_moderator(auth.uid()));

drop policy if exists "moderation_logs_select_moderators" on public.moderation_logs;
create policy "moderation_logs_select_moderators"
on public.moderation_logs for select
using (public.is_moderator(auth.uid()));

drop policy if exists "moderation_logs_insert_moderators" on public.moderation_logs;
create policy "moderation_logs_insert_moderators"
on public.moderation_logs for insert
with check (public.is_moderator(auth.uid()));

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own"
on public.posts for insert
with check (
  auth.uid() = user_id
  and (
    community_id is null
    or exists (
      select 1
      from public.communities c
      where c.id = posts.community_id
        and c.owner_id = auth.uid()
    )
    or exists (
      select 1
      from public.community_members cm
      where cm.community_id = posts.community_id
        and cm.user_id = auth.uid()
        and cm.status = 'active'
    )
  )
  and not exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid()
      and pr.suspended_until is not null
      and pr.suspended_until > now()
  )
);

drop policy if exists "comments_insert_own_if_post_visible" on public.comments;
create policy "comments_insert_own_if_post_visible"
on public.comments for insert
with check (
  auth.uid() = user_id
  and not exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid()
      and pr.suspended_until is not null
      and pr.suspended_until > now()
  )
  and exists (
    select 1
    from public.posts p
    where p.id = comments.post_id
      and (
        (
          p.community_id is null
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and auth.uid() is not null
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and auth.uid() is not null
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
        or (
          p.community_id is not null
          and auth.uid() is not null
          and (
            exists (
              select 1
              from public.communities c
              where c.id = p.community_id
                and c.owner_id = auth.uid()
            )
            or exists (
              select 1
              from public.community_members cm
              where cm.community_id = p.community_id
                and cm.user_id = auth.uid()
                and cm.status = 'active'
            )
          )
          and (
            p.user_id = auth.uid()
            or p.visibility = 'public'
            or (
              p.visibility = 'followers'
              and exists (
                select 1
                from public.follows f
                where f.follower_id = auth.uid()
                  and f.following_id = p.user_id
              )
            )
            or (
              p.visibility = 'church'
              and p.church_id is not null
              and exists (
                select 1
                from public.profiles pr
                where pr.id = auth.uid()
                  and pr.church_id = p.church_id
              )
            )
          )
        )
      )
  )
);

drop policy if exists "stories_insert_own" on public.stories;
create policy "stories_insert_own"
on public.stories for insert
with check (
  auth.uid() = user_id
  and not exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid()
      and pr.suspended_until is not null
      and pr.suspended_until > now()
  )
);

drop policy if exists "alerts_insert_own" on public.alerts;
create policy "alerts_insert_own"
on public.alerts for insert
with check (
  auth.uid() = user_id
  and not exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid()
      and pr.suspended_until is not null
      and pr.suspended_until > now()
  )
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

drop trigger if exists trg_posts_reputation on public.posts;
create or replace function public.posts_reputation_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.apply_reputation_delta(new.user_id, 2, 'post_created');
  return new;
end;
$$;
create trigger trg_posts_reputation
after insert on public.posts
for each row execute function public.posts_reputation_trigger();

drop trigger if exists trg_alerts_reputation on public.alerts;
create or replace function public.alerts_reputation_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.apply_reputation_delta(new.user_id, 3, 'alert_created');
  return new;
end;
$$;
create trigger trg_alerts_reputation
after insert on public.alerts
for each row execute function public.alerts_reputation_trigger();

commit;
