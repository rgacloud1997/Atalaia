begin;

create schema if not exists extensions;

do $$
declare
  r record;
begin
  for r in
    select
      n.nspname as schema_name,
      p.proname as func_name,
      pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.proconfig is not null
      and 'search_path=public' = any (p.proconfig)
  loop
    execute format(
      'alter function %I.%I(%s) set search_path = public, extensions',
      r.schema_name,
      r.func_name,
      r.args
    );
  end loop;
end
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'postgis') then
    begin
      execute 'alter extension postgis set schema extensions';
    exception
      when sqlstate '0A000' then
        null;
      when sqlstate '42501' then
        null;
    end;
  end if;
  if exists (select 1 from pg_extension where extname = 'unaccent') then
    begin
      execute 'alter extension unaccent set schema extensions';
    exception
      when sqlstate '0A000' then
        null;
      when sqlstate '42501' then
        null;
    end;
  end if;
end
$$;

do $$
begin
  if to_regclass('public.spatial_ref_sys') is not null then
    begin
      execute 'alter table public.spatial_ref_sys enable row level security';
      execute 'drop policy if exists "spatial_ref_sys_service_only" on public.spatial_ref_sys';
      execute 'create policy "spatial_ref_sys_service_only" on public.spatial_ref_sys for all using (coalesce(auth.role(), '''') = ''service_role'') with check (coalesce(auth.role(), '''') = ''service_role'')';
    exception
      when sqlstate '42501' then
        null;
    end;
  end if;
end
$$;

alter table if exists public.locations_geom_import enable row level security;
drop policy if exists "locations_geom_import_service_only" on public.locations_geom_import;
create policy "locations_geom_import_service_only"
on public.locations_geom_import for all
using (coalesce(auth.role(), '') = 'service_role')
with check (coalesce(auth.role(), '') = 'service_role');

drop policy if exists "ad_impressions_insert_public" on public.ad_impressions;
drop policy if exists "ad_clicks_insert_public" on public.ad_clicks;

drop policy if exists "ad_impressions_insert_service_only" on public.ad_impressions;
create policy "ad_impressions_insert_service_only"
on public.ad_impressions for insert
with check (coalesce(auth.role(), '') = 'service_role');

drop policy if exists "ad_clicks_insert_service_only" on public.ad_clicks;
create policy "ad_clicks_insert_service_only"
on public.ad_clicks for insert
with check (coalesce(auth.role(), '') = 'service_role');

commit;
