begin;

create schema if not exists extensions;

-- Try to move postgis out of public schema (may require elevated privileges).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'postgis') then
    begin
      alter extension postgis set schema extensions;
    exception
      when others then
        raise notice 'WARN: could not move postgis extension to schema extensions (%).', sqlerrm;
    end;
  end if;
end;
$$;

-- If postgis cannot be moved (or is still in public), at least revoke EXECUTE from anon/authenticated
-- on the flagged SECURITY DEFINER functions.
do $$
begin
  if to_regprocedure('public.st_estimatedextent(text,text)') is not null then
    revoke execute on function public.st_estimatedextent(text, text) from anon, authenticated, public;
  end if;
  if to_regprocedure('public.st_estimatedextent(text,text,text)') is not null then
    revoke execute on function public.st_estimatedextent(text, text, text) from anon, authenticated, public;
  end if;
  if to_regprocedure('public.st_estimatedextent(text,text,text,boolean)') is not null then
    revoke execute on function public.st_estimatedextent(text, text, text, boolean) from anon, authenticated, public;
  end if;
end;
$$;

-- Fix advisor error: enable RLS on spatial_ref_sys (if present) and keep it readable.
do $$
begin
  if to_regclass('public.spatial_ref_sys') is not null then
    alter table public.spatial_ref_sys enable row level security;

    -- Allow everyone to read (this table is standard metadata).
    drop policy if exists "spatial_ref_sys_select_all" on public.spatial_ref_sys;
    create policy "spatial_ref_sys_select_all"
    on public.spatial_ref_sys for select
    using (true);

    -- Only service_role can write.
    drop policy if exists "spatial_ref_sys_service_only" on public.spatial_ref_sys;
    create policy "spatial_ref_sys_service_only"
    on public.spatial_ref_sys for all
    using (coalesce(auth.role(), '') = 'service_role')
    with check (coalesce(auth.role(), '') = 'service_role');
  end if;
end;
$$;

commit;
