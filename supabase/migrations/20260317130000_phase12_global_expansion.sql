begin;

create table if not exists public.user_locale_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  locale_code text not null default 'pt-BR',
  timezone_name text,
  country_code text,
  receive_global_content boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_user_locale_preferences_updated_at on public.user_locale_preferences;
create trigger trg_user_locale_preferences_updated_at
before update on public.user_locale_preferences
for each row execute function public.set_updated_at();

alter table public.user_locale_preferences enable row level security;

drop policy if exists "user_locale_preferences_select_own" on public.user_locale_preferences;
drop policy if exists "user_locale_preferences_upsert_own" on public.user_locale_preferences;
drop policy if exists "user_locale_preferences_admin_all" on public.user_locale_preferences;

create policy "user_locale_preferences_select_own"
on public.user_locale_preferences for select
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or auth.uid() = user_id
);

create policy "user_locale_preferences_upsert_own"
on public.user_locale_preferences for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or auth.uid() = user_id
);

create policy "user_locale_preferences_update_own"
on public.user_locale_preferences for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or auth.uid() = user_id
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
  or auth.uid() = user_id
);

create table if not exists public.content_translations (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  field_name text not null,
  locale_code text not null,
  translated_text text not null,
  source_language text,
  provider text,
  created_at timestamptz not null default now()
);

create unique index if not exists content_translations_entity_field_locale_unique
on public.content_translations (entity_type, entity_id, field_name, locale_code);

create index if not exists idx_content_translations_entity_id
on public.content_translations (entity_type, entity_id);

alter table public.content_translations enable row level security;

drop policy if exists "content_translations_select_public" on public.content_translations;
drop policy if exists "content_translations_write_admin" on public.content_translations;

create policy "content_translations_select_public"
on public.content_translations for select
using (true);

create policy "content_translations_insert_admin"
on public.content_translations for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "content_translations_update_admin"
on public.content_translations for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "content_translations_delete_admin"
on public.content_translations for delete
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create table if not exists public.app_regions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country_code text,
  is_active boolean not null default true,
  launch_stage text not null default 'beta',
  default_locale text,
  created_at timestamptz not null default now()
);

create index if not exists idx_app_regions_active_stage on public.app_regions (is_active, launch_stage);
create index if not exists idx_app_regions_country_code on public.app_regions (country_code);

alter table public.app_regions enable row level security;

drop policy if exists "app_regions_select_public" on public.app_regions;
drop policy if exists "app_regions_write_admin" on public.app_regions;

create policy "app_regions_select_public"
on public.app_regions for select
using (is_active and launch_stage <> 'disabled');

create policy "app_regions_insert_admin"
on public.app_regions for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "app_regions_update_admin"
on public.app_regions for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "app_regions_delete_admin"
on public.app_regions for delete
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create table if not exists public.feature_rollouts (
  id uuid primary key default gen_random_uuid(),
  feature_key text not null,
  region_id uuid references public.app_regions(id) on delete cascade,
  is_enabled boolean not null default false,
  config jsonb,
  created_at timestamptz not null default now(),
  constraint feature_rollouts_feature_region_unique unique (feature_key, region_id)
);

create index if not exists idx_feature_rollouts_feature_key on public.feature_rollouts (feature_key);
create index if not exists idx_feature_rollouts_region_id on public.feature_rollouts (region_id);
create index if not exists idx_feature_rollouts_enabled on public.feature_rollouts (is_enabled);

alter table public.feature_rollouts enable row level security;

drop policy if exists "feature_rollouts_select_admin" on public.feature_rollouts;
drop policy if exists "feature_rollouts_write_admin" on public.feature_rollouts;

create policy "feature_rollouts_select_admin"
on public.feature_rollouts for select
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "feature_rollouts_insert_admin"
on public.feature_rollouts for insert
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "feature_rollouts_update_admin"
on public.feature_rollouts for update
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
)
with check (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create policy "feature_rollouts_delete_admin"
on public.feature_rollouts for delete
using (
  coalesce(auth.role(), '') = 'service_role'
  or public.is_moderator(auth.uid())
);

create or replace function public.get_content_translation(
  p_entity_type text,
  p_entity_id uuid,
  p_field_name text,
  p_locale_code text
)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select ct.translated_text
  from public.content_translations ct
  where ct.entity_type = p_entity_type
    and ct.entity_id = p_entity_id
    and ct.field_name = p_field_name
    and ct.locale_code = p_locale_code
  limit 1;
$$;

create or replace function public.resolve_app_region(
  p_country_code text
)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select r.id
  from public.app_regions r
  where r.is_active
    and r.launch_stage <> 'disabled'
    and lower(coalesce(r.country_code, '')) = lower(coalesce(p_country_code, ''))
  order by
    (r.launch_stage = 'public') desc,
    (r.launch_stage = 'beta') desc,
    r.created_at asc
  limit 1;
$$;

create or replace function public.get_enabled_feature_rollouts(
  p_region_id uuid default null
)
returns table (
  feature_key text,
  config jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select fr.feature_key, fr.config
  from public.feature_rollouts fr
  left join public.app_regions r on r.id = fr.region_id
  where fr.is_enabled
    and (fr.region_id is null or fr.region_id = p_region_id)
    and (
      fr.region_id is null
      or (r.is_active and r.launch_stage <> 'disabled')
    )
  order by fr.feature_key asc;
$$;

revoke all on function public.get_content_translation(text, uuid, text, text) from public;
revoke all on function public.resolve_app_region(text) from public;
revoke all on function public.get_enabled_feature_rollouts(uuid) from public;

grant execute on function public.get_content_translation(text, uuid, text, text) to anon, authenticated;
grant execute on function public.resolve_app_region(text) to anon, authenticated;
grant execute on function public.get_enabled_feature_rollouts(uuid) to anon, authenticated;

commit;
