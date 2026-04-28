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
    begin
      alter table public.spatial_ref_sys enable row level security;
    exception
      when insufficient_privilege then
        raise notice 'WARN: could not enable RLS on public.spatial_ref_sys (not owner).';
        return;
    end;

    -- Allow everyone to read (this table is standard metadata).
    begin
      drop policy if exists "spatial_ref_sys_select_all" on public.spatial_ref_sys;
      create policy "spatial_ref_sys_select_all"
      on public.spatial_ref_sys for select
      using (true);
    exception
      when insufficient_privilege then
        raise notice 'WARN: could not create SELECT policy on public.spatial_ref_sys (not owner).';
    end;

    -- Only service_role can write.
    begin
      drop policy if exists "spatial_ref_sys_service_only" on public.spatial_ref_sys;
      create policy "spatial_ref_sys_service_only"
      on public.spatial_ref_sys for all
      using (coalesce(auth.role(), '') = 'service_role')
      with check (coalesce(auth.role(), '') = 'service_role');
    exception
      when insufficient_privilege then
        raise notice 'WARN: could not create service-only policy on public.spatial_ref_sys (not owner).';
    end;
  end if;
end;
$$;

commit;
