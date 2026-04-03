begin;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'ad_campaign_status'
  ) then
    create type public.ad_campaign_status as enum ('draft', 'active', 'paused', 'completed', 'rejected');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'ad_campaign_objective'
  ) then
    create type public.ad_campaign_objective as enum ('traffic', 'awareness', 'promotion', 'community', 'event');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'ad_creative_type'
  ) then
    create type public.ad_creative_type as enum ('image', 'video', 'text');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'ad_target_scope'
  ) then
    create type public.ad_target_scope as enum ('world', 'country', 'state', 'city', 'community');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'ad_placement'
  ) then
    create type public.ad_placement as enum ('feed', 'map_pin', 'story_slot', 'community_feed');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'map_pin_kind'
  ) then
    create type public.map_pin_kind as enum ('sponsored');
  end if;
end $$;

do $do$
begin
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'is_moderator'
      and pg_get_function_identity_arguments(p.oid) in ('uuid', 'p_user_id uuid')
  ) then
    execute $sql$
      create or replace function public.is_moderator(p_user_id uuid)
      returns boolean
      language plpgsql
      stable
      set search_path = public
      as $fn$
      declare
        v_has_verification_type boolean;
        v_has_verified_type boolean;
        v_result boolean := false;
      begin
        if p_user_id is null then
          return false;
        end if;
        if to_regclass('public.profiles') is null then
          return false;
        end if;

        select exists (
          select 1
          from pg_attribute a
          where a.attrelid = to_regclass('public.profiles')
            and a.attname = 'verification_type'
            and a.attnum > 0
            and not a.attisdropped
        ) into v_has_verification_type;

        if v_has_verification_type then
          execute $q$
            select exists (
              select 1
              from public.profiles pr
              where pr.id = $1
                and pr.verification_type::text in ('moderator','admin')
            )
          $q$ into v_result using p_user_id;
          return coalesce(v_result, false);
        end if;

        select exists (
          select 1
          from pg_attribute a
          where a.attrelid = to_regclass('public.profiles')
            and a.attname = 'verified_type'
            and a.attnum > 0
            and not a.attisdropped
        ) into v_has_verified_type;

        if v_has_verified_type then
          execute $q$
            select exists (
              select 1
              from public.profiles pr
              where pr.id = $1
                and coalesce(pr.is_verified, false) = true
                and lower(coalesce(pr.verified_type, '')) in ('moderator','admin')
            )
          $q$ into v_result using p_user_id;
          return coalesce(v_result, false);
        end if;

        return false;
      end;
      $fn$;
    $sql$;
  end if;
end;
$do$;

create table if not exists public.advertisers (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete set null,
  name text not null,
  contact_email text,
  contact_phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  advertiser_id uuid not null references public.advertisers(id) on delete cascade,
  title text not null,
  description text,
  objective public.ad_campaign_objective not null,
  status public.ad_campaign_status not null default 'draft',
  budget_total numeric(12,2),
  budget_daily numeric(12,2),
  start_date timestamptz,
  end_date timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_ad_campaigns_updated_at on public.ad_campaigns;
create trigger trg_ad_campaigns_updated_at
before update on public.ad_campaigns
for each row execute function public.set_updated_at();

create table if not exists public.ad_creatives (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  media_file_id uuid references public.media_files(id) on delete set null,
  creative_type public.ad_creative_type not null,
  headline text,
  body text,
  cta_label text,
  target_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.ad_targets (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  scope public.ad_target_scope not null,
  location_id uuid references public.locations(id) on delete cascade,
  community_id uuid references public.communities(id) on delete cascade,
  placement public.ad_placement not null,
  priority int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint ad_targets_location_or_community_chk check (
    (scope = 'community' and community_id is not null)
    or (scope <> 'community' and location_id is not null)
    or (scope = 'world' and location_id is null and community_id is null)
  )
);

create table if not exists public.ad_impressions (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  creative_id uuid not null references public.ad_creatives(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  location_id uuid references public.locations(id) on delete set null,
  community_id uuid references public.communities(id) on delete set null,
  placement public.ad_placement,
  viewed_at timestamptz not null default now(),
  session_id text
);

create index if not exists idx_ad_impressions_campaign_id on public.ad_impressions (campaign_id);
create index if not exists idx_ad_impressions_creative_id on public.ad_impressions (creative_id);
create index if not exists idx_ad_impressions_viewed_at_desc on public.ad_impressions (viewed_at desc);
create index if not exists idx_ad_impressions_placement on public.ad_impressions (placement);
create index if not exists idx_ad_impressions_session_id on public.ad_impressions (session_id);

create table if not exists public.ad_clicks (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  creative_id uuid not null references public.ad_creatives(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  location_id uuid references public.locations(id) on delete set null,
  community_id uuid references public.communities(id) on delete set null,
  placement public.ad_placement,
  clicked_at timestamptz not null default now(),
  session_id text
);

create index if not exists idx_ad_clicks_campaign_id on public.ad_clicks (campaign_id);
create index if not exists idx_ad_clicks_creative_id on public.ad_clicks (creative_id);
create index if not exists idx_ad_clicks_clicked_at_desc on public.ad_clicks (clicked_at desc);
create index if not exists idx_ad_clicks_placement on public.ad_clicks (placement);
create index if not exists idx_ad_clicks_session_id on public.ad_clicks (session_id);

create table if not exists public.sponsored_map_pins (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  creative_id uuid not null references public.ad_creatives(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete cascade,
  pin_label text,
  pin_type public.map_pin_kind not null default 'sponsored',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_sponsored_map_pins_location_id on public.sponsored_map_pins (location_id);
create index if not exists idx_sponsored_map_pins_active on public.sponsored_map_pins (is_active);

alter table public.advertisers enable row level security;
alter table public.ad_campaigns enable row level security;
alter table public.ad_creatives enable row level security;
alter table public.ad_targets enable row level security;
alter table public.ad_impressions enable row level security;
alter table public.ad_clicks enable row level security;
alter table public.sponsored_map_pins enable row level security;

drop policy if exists "advertisers_select_admin_or_owner" on public.advertisers;
drop policy if exists "advertisers_select_active_public" on public.advertisers;
drop policy if exists "advertisers_insert_admin" on public.advertisers;
drop policy if exists "advertisers_update_admin" on public.advertisers;
drop policy if exists "advertisers_delete_admin" on public.advertisers;

drop policy if exists "ad_campaigns_select_admin_or_owner" on public.ad_campaigns;
drop policy if exists "ad_campaigns_select_active_public" on public.ad_campaigns;
drop policy if exists "ad_campaigns_insert_admin" on public.ad_campaigns;
drop policy if exists "ad_campaigns_update_admin" on public.ad_campaigns;
drop policy if exists "ad_campaigns_delete_admin" on public.ad_campaigns;

drop policy if exists "ad_creatives_select_admin_or_owner" on public.ad_creatives;
drop policy if exists "ad_creatives_select_active_public" on public.ad_creatives;
drop policy if exists "ad_creatives_insert_admin" on public.ad_creatives;
drop policy if exists "ad_creatives_update_admin" on public.ad_creatives;
drop policy if exists "ad_creatives_delete_admin" on public.ad_creatives;

drop policy if exists "ad_targets_select_admin_or_owner" on public.ad_targets;
drop policy if exists "ad_targets_select_active_public" on public.ad_targets;
drop policy if exists "ad_targets_insert_admin" on public.ad_targets;
drop policy if exists "ad_targets_update_admin" on public.ad_targets;
drop policy if exists "ad_targets_delete_admin" on public.ad_targets;

drop policy if exists "sponsored_map_pins_select_admin_or_owner" on public.sponsored_map_pins;
drop policy if exists "sponsored_map_pins_select_active_public" on public.sponsored_map_pins;
drop policy if exists "sponsored_map_pins_insert_admin" on public.sponsored_map_pins;
drop policy if exists "sponsored_map_pins_update_admin" on public.sponsored_map_pins;
drop policy if exists "sponsored_map_pins_delete_admin" on public.sponsored_map_pins;

drop policy if exists "ad_impressions_insert_public" on public.ad_impressions;
drop policy if exists "ad_clicks_insert_public" on public.ad_clicks;

create policy "advertisers_select_admin_or_owner"
on public.advertisers for select
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or owner_user_id = auth.uid()
);

create policy "advertisers_select_active_public"
on public.advertisers for select
using (is_active);

create policy "advertisers_insert_admin"
on public.advertisers for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "advertisers_update_admin"
on public.advertisers for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "advertisers_delete_admin"
on public.advertisers for delete
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_campaigns_select_admin_or_owner"
on public.ad_campaigns for select
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or exists (
    select 1
    from public.advertisers a
    where a.id = ad_campaigns.advertiser_id
      and a.owner_user_id = auth.uid()
  )
);

create policy "ad_campaigns_select_active_public"
on public.ad_campaigns for select
using (
  status = 'active'
  and (start_date is null or start_date <= now())
  and (end_date is null or end_date >= now())
  and exists (
    select 1
    from public.advertisers a
    where a.id = ad_campaigns.advertiser_id
      and a.is_active
  )
);

create policy "ad_campaigns_insert_admin"
on public.ad_campaigns for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_campaigns_update_admin"
on public.ad_campaigns for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_campaigns_delete_admin"
on public.ad_campaigns for delete
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_creatives_select_admin_or_owner"
on public.ad_creatives for select
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or exists (
    select 1
    from public.ad_campaigns c
    join public.advertisers a on a.id = c.advertiser_id
    where c.id = ad_creatives.campaign_id
      and a.owner_user_id = auth.uid()
  )
);

create policy "ad_creatives_select_active_public"
on public.ad_creatives for select
using (
  is_active
  and exists (
    select 1
    from public.ad_campaigns c
    where c.id = ad_creatives.campaign_id
      and c.status = 'active'
      and (c.start_date is null or c.start_date <= now())
      and (c.end_date is null or c.end_date >= now())
  )
);

create policy "ad_creatives_insert_admin"
on public.ad_creatives for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_creatives_update_admin"
on public.ad_creatives for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_creatives_delete_admin"
on public.ad_creatives for delete
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_targets_select_admin_or_owner"
on public.ad_targets for select
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or exists (
    select 1
    from public.ad_campaigns c
    join public.advertisers a on a.id = c.advertiser_id
    where c.id = ad_targets.campaign_id
      and a.owner_user_id = auth.uid()
  )
);

create policy "ad_targets_select_active_public"
on public.ad_targets for select
using (
  is_active
  and exists (
    select 1
    from public.ad_campaigns c
    where c.id = ad_targets.campaign_id
      and c.status = 'active'
      and (c.start_date is null or c.start_date <= now())
      and (c.end_date is null or c.end_date >= now())
  )
);

create policy "ad_targets_insert_admin"
on public.ad_targets for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_targets_update_admin"
on public.ad_targets for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_targets_delete_admin"
on public.ad_targets for delete
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "sponsored_map_pins_select_admin_or_owner"
on public.sponsored_map_pins for select
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or exists (
    select 1
    from public.ad_campaigns c
    join public.advertisers a on a.id = c.advertiser_id
    where c.id = sponsored_map_pins.campaign_id
      and a.owner_user_id = auth.uid()
  )
);

create policy "sponsored_map_pins_select_active_public"
on public.sponsored_map_pins for select
using (
  is_active
  and exists (
    select 1
    from public.ad_campaigns c
    join public.ad_creatives cr on cr.campaign_id = c.id
    where c.id = sponsored_map_pins.campaign_id
      and cr.id = sponsored_map_pins.creative_id
      and c.status = 'active'
      and (c.start_date is null or c.start_date <= now())
      and (c.end_date is null or c.end_date >= now())
      and cr.is_active
  )
);

create policy "sponsored_map_pins_insert_admin"
on public.sponsored_map_pins for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "sponsored_map_pins_update_admin"
on public.sponsored_map_pins for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "sponsored_map_pins_delete_admin"
on public.sponsored_map_pins for delete
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "ad_impressions_insert_public"
on public.ad_impressions for insert
with check (true);

create policy "ad_clicks_insert_public"
on public.ad_clicks for insert
with check (true);

create or replace function public.ads_select_feed_candidates(
  p_scope text,
  p_location_id uuid default null,
  p_community_id uuid default null,
  p_placement public.ad_placement default 'feed',
  p_limit int default 10
)
returns table (
  campaign_id uuid,
  creative_id uuid,
  advertiser_name text,
  creative_type text,
  headline text,
  body text,
  cta_label text,
  target_url text,
  media_url text,
  priority int,
  scope_rank int
)
language sql
stable
security definer
set search_path = public
as $$
  with ctx as (
    select
      p_scope::text as scope,
      p_location_id as location_id,
      p_community_id as community_id,
      case
        when p_location_id is null then null::text
        else (select l.path from public.locations l where l.id = p_location_id)
      end as location_path
  ),
  candidates as (
    select
      c.id as campaign_id,
      cr.id as creative_id,
      a.name as advertiser_name,
      cr.creative_type::text as creative_type,
      coalesce(cr.headline, c.title) as headline,
      cr.body,
      cr.cta_label,
      cr.target_url,
      mf.url as media_url,
      t.priority as priority,
      case t.scope
        when 'city' then 4
        when 'state' then 3
        when 'country' then 2
        when 'world' then 1
        when 'community' then 5
        else 0
      end as scope_rank
    from public.ad_targets t
    join public.ad_campaigns c on c.id = t.campaign_id
    join public.advertisers a on a.id = c.advertiser_id
    join public.ad_creatives cr on cr.campaign_id = c.id
    left join public.media_files mf on mf.id = cr.media_file_id
    cross join ctx
    where a.is_active
      and c.status = 'active'
      and (c.start_date is null or c.start_date <= now())
      and (c.end_date is null or c.end_date >= now())
      and cr.is_active
      and t.is_active
      and t.placement = p_placement
      and (
        (t.scope = 'community' and ctx.community_id is not null and t.community_id = ctx.community_id)
        or (t.scope = 'world' and t.location_id is null and t.community_id is null)
        or (
          t.scope <> 'community'
          and ctx.location_path is not null
          and exists (
            select 1
            from public.locations tl
            where tl.id = t.location_id
              and ctx.location_path like tl.path || '%'
          )
        )
      )
  )
  select *
  from candidates
  order by scope_rank desc, priority desc, campaign_id asc, creative_id asc
  limit greatest(p_limit, 1);
$$;

create or replace function public.get_feed_with_ads(
  p_scope text,
  p_location_id uuid default null,
  p_community_id uuid default null,
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  item_type text,
  post_id uuid,
  post_user_id uuid,
  post_username text,
  post_is_verified boolean,
  post_title text,
  post_content text,
  post_created_at timestamptz,
  post_location_id uuid,
  post_location_path text,
  post_location_name text,
  post_scope text,
  post_type text,
  post_media_type text,
  post_media_url text,
  campaign_id uuid,
  creative_id uuid,
  advertiser_name text,
  creative_type text,
  headline text,
  body text,
  cta_label text,
  target_url text,
  media_url text,
  placement text
)
language plpgsql
stable
set search_path = public
as $$
declare
  v_limit int := greatest(p_limit, 1);
  v_offset int := greatest(p_offset, 0);
  v_total int := greatest(p_limit, 1) + greatest(p_offset, 0);
  v_ads_needed int := (v_total / 16) + 3;
  v_org_needed int := v_total;
  v_placement public.ad_placement := case when lower(coalesce(p_scope, '')) = 'community' then 'community_feed' else 'feed' end;
begin
  return query
  with organic as (
    select
      row_number() over () as rn,
      f.*
    from public.get_feed_by_scope(
      p_scope,
      p_location_id,
      p_community_id,
      null,
      'recent',
      null,
      v_org_needed,
      null,
      null
    ) f
  ),
  organic_out as (
    select
      (rn + ((rn - 1) / 15))::int as out_pos,
      'post'::text as item_type,
      id as post_id,
      user_id as post_user_id,
      username as post_username,
      is_verified as post_is_verified,
      title as post_title,
      content as post_content,
      created_at as post_created_at,
      location_id as post_location_id,
      location_path as post_location_path,
      location_name as post_location_name,
      scope as post_scope,
      post_type::text as post_type,
      media_type as post_media_type,
      media_url as post_media_url,
      null::uuid as campaign_id,
      null::uuid as creative_id,
      null::text as advertiser_name,
      null::text as creative_type,
      null::text as headline,
      null::text as body,
      null::text as cta_label,
      null::text as target_url,
      null::text as media_url,
      v_placement::text as placement
    from organic
  ),
  ads as (
    select
      row_number() over () as rn,
      c.*
    from public.ads_select_feed_candidates(p_scope, p_location_id, p_community_id, v_placement, v_ads_needed) c
  ),
  ad_out as (
    select
      (rn * 16)::int as out_pos,
      'ad'::text as item_type,
      null::uuid as post_id,
      null::uuid as post_user_id,
      null::text as post_username,
      null::boolean as post_is_verified,
      null::text as post_title,
      null::text as post_content,
      null::timestamptz as post_created_at,
      null::uuid as post_location_id,
      null::text as post_location_path,
      null::text as post_location_name,
      null::text as post_scope,
      null::text as post_type,
      null::text as post_media_type,
      null::text as post_media_url,
      campaign_id,
      creative_id,
      advertiser_name,
      creative_type,
      headline,
      body,
      cta_label,
      target_url,
      media_url,
      v_placement::text as placement
    from ads
  ),
  combined as (
    select * from organic_out
    union all
    select * from ad_out
  )
  select
    item_type,
    post_id,
    post_user_id,
    post_username,
    post_is_verified,
    post_title,
    post_content,
    post_created_at,
    post_location_id,
    post_location_path,
    post_location_name,
    post_scope,
    post_type,
    post_media_type,
    post_media_url,
    campaign_id,
    creative_id,
    advertiser_name,
    creative_type,
    headline,
    body,
    cta_label,
    target_url,
    media_url,
    placement
  from combined
  order by out_pos asc
  offset v_offset
  limit v_limit;
end;
$$;

create or replace function public.get_sponsored_pins(
  p_scope text,
  p_location_id uuid default null,
  p_bounds jsonb default null
)
returns table (
  id uuid,
  campaign_id uuid,
  creative_id uuid,
  location_id uuid,
  location_name text,
  center_lat double precision,
  center_lng double precision,
  pin_label text,
  advertiser_name text,
  headline text,
  cta_label text,
  target_url text,
  media_url text
)
language sql
stable
security definer
set search_path = public
as $$
  with ctx as (
    select
      p_location_id as location_id,
      case
        when p_location_id is null then null::text
        else (select l.path from public.locations l where l.id = p_location_id)
      end as location_path
  )
  select
    p.id,
    p.campaign_id,
    p.creative_id,
    p.location_id,
    l.name as location_name,
    l.center_lat,
    l.center_lng,
    p.pin_label,
    a.name as advertiser_name,
    coalesce(cr.headline, c.title) as headline,
    cr.cta_label,
    cr.target_url,
    mf.url as media_url
  from public.sponsored_map_pins p
  join public.locations l on l.id = p.location_id
  join public.ad_creatives cr on cr.id = p.creative_id
  join public.ad_campaigns c on c.id = p.campaign_id
  join public.advertisers a on a.id = c.advertiser_id
  left join public.media_files mf on mf.id = cr.media_file_id
  cross join ctx
  where p.is_active
    and cr.is_active
    and a.is_active
    and c.status = 'active'
    and (c.start_date is null or c.start_date <= now())
    and (c.end_date is null or c.end_date >= now())
    and (
      ctx.location_path is null
      or ctx.location_path like l.path || '%'
      or l.path like ctx.location_path || '%'
    );
$$;

create or replace function public.track_ad_impression(
  p_campaign_id uuid,
  p_creative_id uuid,
  p_placement text,
  p_location_id uuid default null,
  p_community_id uuid default null,
  p_session_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.ad_impressions (campaign_id, creative_id, user_id, location_id, community_id, placement, session_id)
  values (
    p_campaign_id,
    p_creative_id,
    auth.uid(),
    p_location_id,
    p_community_id,
    nullif(trim(lower(p_placement)), '')::public.ad_placement,
    nullif(trim(p_session_id), '')
  );
end;
$$;

create or replace function public.track_ad_click(
  p_campaign_id uuid,
  p_creative_id uuid,
  p_placement text,
  p_location_id uuid default null,
  p_community_id uuid default null,
  p_session_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.ad_clicks (campaign_id, creative_id, user_id, location_id, community_id, placement, session_id)
  values (
    p_campaign_id,
    p_creative_id,
    auth.uid(),
    p_location_id,
    p_community_id,
    nullif(trim(lower(p_placement)), '')::public.ad_placement,
    nullif(trim(p_session_id), '')
  );
end;
$$;

create or replace function public.get_ad_campaign_metrics(p_campaign_id uuid)
returns table (
  placement text,
  impressions bigint,
  clicks bigint,
  ctr double precision
)
language sql
stable
security definer
set search_path = public
as $$
  with imp as (
    select coalesce(i.placement::text, 'unknown') as placement, count(*)::bigint as impressions
    from public.ad_impressions i
    where i.campaign_id = p_campaign_id
    group by coalesce(i.placement::text, 'unknown')
  ),
  clk as (
    select coalesce(c.placement::text, 'unknown') as placement, count(*)::bigint as clicks
    from public.ad_clicks c
    where c.campaign_id = p_campaign_id
    group by coalesce(c.placement::text, 'unknown')
  )
  select
    coalesce(imp.placement, clk.placement) as placement,
    coalesce(imp.impressions, 0) as impressions,
    coalesce(clk.clicks, 0) as clicks,
    case
      when coalesce(imp.impressions, 0) = 0 then 0::double precision
      else (coalesce(clk.clicks, 0)::double precision / imp.impressions::double precision)
    end as ctr
  from imp
  full outer join clk using (placement)
  order by placement asc;
$$;

grant execute on function public.ads_select_feed_candidates(text, uuid, uuid, public.ad_placement, int) to anon, authenticated;
grant execute on function public.get_feed_with_ads(text, uuid, uuid, int, int) to anon, authenticated;
grant execute on function public.get_sponsored_pins(text, uuid, jsonb) to anon, authenticated;
grant execute on function public.track_ad_impression(uuid, uuid, text, uuid, uuid, text) to anon, authenticated;
grant execute on function public.track_ad_click(uuid, uuid, text, uuid, uuid, text) to anon, authenticated;
grant execute on function public.get_ad_campaign_metrics(uuid) to anon, authenticated;

commit;
