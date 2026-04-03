begin;

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete restrict,
  community_id uuid references public.communities(id) on delete cascade,
  title text not null,
  description text not null,
  image_url text,
  goal_amount numeric(12, 2) not null,
  raised_amount numeric(12, 2) not null default 0,
  currency text not null default 'BRL',
  category text not null,
  status text not null default 'active',
  deadline timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint campaigns_goal_amount_nonneg check (goal_amount >= 0),
  constraint campaigns_raised_amount_nonneg check (raised_amount >= 0),
  constraint campaigns_currency_check check (currency in ('BRL')) not valid,
  constraint campaigns_category_check check (
    category in (
      'medical',
      'emergency',
      'social',
      'church',
      'mission',
      'education',
      'disaster',
      'community_project'
    )
  ) not valid,
  constraint campaigns_status_check check (status in ('draft', 'active', 'closed', 'cancelled')) not valid
);

create index if not exists idx_campaigns_location_id on public.campaigns (location_id);
create index if not exists idx_campaigns_community_id on public.campaigns (community_id);
create index if not exists idx_campaigns_status_deadline on public.campaigns (status, deadline asc nulls last);
create index if not exists idx_campaigns_created_at on public.campaigns (created_at desc);

create trigger trg_campaigns_updated_at
before update on public.campaigns
for each row execute function public.set_updated_at();

create table if not exists public.donations (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  donor_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(12, 2) not null,
  currency text not null default 'BRL',
  payment_method text not null,
  status text not null default 'succeeded',
  created_at timestamptz not null default now(),
  constraint donations_amount_positive check (amount > 0),
  constraint donations_currency_check check (currency in ('BRL')) not valid,
  constraint donations_payment_method_check check (payment_method in ('pix', 'card')) not valid,
  constraint donations_status_check check (status in ('pending', 'succeeded', 'failed', 'refunded')) not valid
);

create index if not exists idx_donations_campaign_created_at on public.donations (campaign_id, created_at desc);
create index if not exists idx_donations_donor_created_at on public.donations (donor_id, created_at desc);

create or replace function public.apply_campaign_donation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  delta numeric(12,2) := 0;
begin
  if tg_op = 'INSERT' then
    if new.status = 'succeeded' then
      delta := new.amount;
    end if;
  elsif tg_op = 'UPDATE' then
    if old.status = 'succeeded' then
      delta := delta - old.amount;
    end if;
    if new.status = 'succeeded' then
      delta := delta + new.amount;
    end if;
  elsif tg_op = 'DELETE' then
    if old.status = 'succeeded' then
      delta := -old.amount;
    end if;
  end if;

  if delta <> 0 then
    update public.campaigns
    set raised_amount = greatest(0, raised_amount + delta)
    where id = coalesce(new.campaign_id, old.campaign_id);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_donations_apply_campaign on public.donations;
create trigger trg_donations_apply_campaign
after insert or update or delete on public.donations
for each row execute function public.apply_campaign_donation();

create table if not exists public.campaign_updates (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  media_url text,
  created_at timestamptz not null default now()
);

create index if not exists idx_campaign_updates_campaign_created_at on public.campaign_updates (campaign_id, created_at desc);

create table if not exists public.campaign_comments (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_campaign_comments_campaign_created_at on public.campaign_comments (campaign_id, created_at desc);

create or replace function public.campaign_can_view(p_campaign_id uuid, p_user_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.campaigns c
    where c.id = p_campaign_id
      and (
        c.community_id is null
        or public.community_can_view(c.community_id, p_user_id)
      )
  );
$$;

create or replace function public.campaign_can_post_in_community(p_community_id uuid, p_user_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    public.community_is_admin(p_community_id, p_user_id)
    or exists (
      select 1
      from public.community_members cm
      where cm.community_id = p_community_id
        and cm.user_id = p_user_id
        and cm.status = 'active'
    );
$$;

alter table public.campaigns enable row level security;
alter table public.donations enable row level security;
alter table public.campaign_updates enable row level security;
alter table public.campaign_comments enable row level security;

drop policy if exists "campaigns_select_visible_or_owner" on public.campaigns;
create policy "campaigns_select_visible_or_owner"
on public.campaigns for select
using (
  (
    status <> 'draft'
    and (
      community_id is null
      or public.community_can_view(community_id, auth.uid())
    )
  )
  or creator_id = auth.uid()
  or (community_id is not null and public.community_is_admin(community_id, auth.uid()))
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "campaigns_insert_own" on public.campaigns;
create policy "campaigns_insert_own"
on public.campaigns for insert
with check (
  creator_id = auth.uid()
  and (
    community_id is null
    or public.campaign_can_post_in_community(community_id, auth.uid())
  )
);

drop policy if exists "campaigns_update_own_or_admin" on public.campaigns;
create policy "campaigns_update_own_or_admin"
on public.campaigns for update
using (
  creator_id = auth.uid()
  or (community_id is not null and public.community_is_admin(community_id, auth.uid()))
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  creator_id = auth.uid()
  or (community_id is not null and public.community_is_admin(community_id, auth.uid()))
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "campaigns_delete_own_or_admin" on public.campaigns;
create policy "campaigns_delete_own_or_admin"
on public.campaigns for delete
using (
  creator_id = auth.uid()
  or (community_id is not null and public.community_is_admin(community_id, auth.uid()))
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "donations_select_if_campaign_viewer" on public.donations;
create policy "donations_select_if_campaign_viewer"
on public.donations for select
using (
  donor_id = auth.uid()
  or exists (
    select 1
    from public.campaigns c
    where c.id = donations.campaign_id
      and (
        c.creator_id = auth.uid()
        or (c.community_id is null)
        or public.community_can_view(c.community_id, auth.uid())
      )
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "donations_insert_self" on public.donations;
create policy "donations_insert_self"
on public.donations for insert
with check (
  donor_id = auth.uid()
  and exists (
    select 1
    from public.campaigns c
    where c.id = donations.campaign_id
      and c.status = 'active'
      and (
        c.community_id is null
        or public.community_can_view(c.community_id, auth.uid())
      )
  )
);

drop policy if exists "donations_update_self" on public.donations;
create policy "donations_update_self"
on public.donations for update
using (
  donor_id = auth.uid()
  or coalesce(auth.role(), '') = 'service_role'
)
with check (
  donor_id = auth.uid()
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "campaign_updates_select_if_campaign_viewer" on public.campaign_updates;
create policy "campaign_updates_select_if_campaign_viewer"
on public.campaign_updates for select
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_updates.campaign_id
      and (
        c.community_id is null
        or public.community_can_view(c.community_id, auth.uid())
      )
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "campaign_updates_insert_creator_or_admin" on public.campaign_updates;
create policy "campaign_updates_insert_creator_or_admin"
on public.campaign_updates for insert
with check (
  author_id = auth.uid()
  and exists (
    select 1
    from public.campaigns c
    where c.id = campaign_updates.campaign_id
      and (
        c.creator_id = auth.uid()
        or (c.community_id is not null and public.community_is_admin(c.community_id, auth.uid()))
      )
  )
);

drop policy if exists "campaign_updates_delete_creator_or_admin" on public.campaign_updates;
create policy "campaign_updates_delete_creator_or_admin"
on public.campaign_updates for delete
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_updates.campaign_id
      and (
        c.creator_id = auth.uid()
        or (c.community_id is not null and public.community_is_admin(c.community_id, auth.uid()))
      )
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "campaign_comments_select_if_campaign_viewer" on public.campaign_comments;
create policy "campaign_comments_select_if_campaign_viewer"
on public.campaign_comments for select
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_comments.campaign_id
      and (
        c.community_id is null
        or public.community_can_view(c.community_id, auth.uid())
      )
  )
  or coalesce(auth.role(), '') = 'service_role'
);

drop policy if exists "campaign_comments_insert_if_campaign_viewer" on public.campaign_comments;
create policy "campaign_comments_insert_if_campaign_viewer"
on public.campaign_comments for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.campaigns c
    where c.id = campaign_comments.campaign_id
      and c.status = 'active'
      and (
        c.community_id is null
        or public.community_can_view(c.community_id, auth.uid())
      )
  )
);

drop policy if exists "campaign_comments_delete_own_or_admin" on public.campaign_comments;
create policy "campaign_comments_delete_own_or_admin"
on public.campaign_comments for delete
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.campaigns c
    where c.id = campaign_comments.campaign_id
      and (c.community_id is not null and public.community_is_admin(c.community_id, auth.uid()))
  )
  or coalesce(auth.role(), '') = 'service_role'
);

create or replace function public.campaigns_by_location(
  p_location_id uuid,
  p_community_id uuid default null,
  p_cursor_created_at timestamptz default null,
  p_limit integer default 24
)
returns table (
  id uuid,
  creator_id uuid,
  community_id uuid,
  title text,
  description text,
  image_url text,
  goal_amount numeric,
  raised_amount numeric,
  currency text,
  category text,
  status text,
  deadline timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  location_id uuid,
  location_path text,
  location_name text,
  center_lat double precision,
  center_lng double precision,
  donations_count integer
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
    c.id,
    c.creator_id,
    c.community_id,
    c.title,
    c.description,
    c.image_url,
    c.goal_amount,
    c.raised_amount,
    c.currency,
    c.category,
    c.status,
    c.deadline,
    c.created_at,
    c.updated_at,
    c.location_id,
    l.path as location_path,
    l.name as location_name,
    l.center_lat,
    l.center_lng,
    (
      select count(1)::int
      from public.donations d
      where d.campaign_id = c.id
        and d.status = 'succeeded'
    ) as donations_count
  from public.campaigns c
  join public.locations l on l.id = c.location_id
  join target t on true
  where t.path is not null
    and (
      l.path = t.path
      or l.path like (t.path || '/%')
    )
    and (
      p_community_id is null
      or c.community_id = p_community_id
    )
    and (
      p_cursor_created_at is null
      or c.created_at < p_cursor_created_at
    )
    and c.status in ('active', 'closed')
  order by
    case when c.status = 'active' then 0 else 1 end,
    c.deadline asc nulls last,
    c.created_at desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.campaigns_by_location(uuid, uuid, timestamptz, integer) to anon, authenticated;

commit;
