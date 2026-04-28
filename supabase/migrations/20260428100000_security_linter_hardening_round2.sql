begin;

-- Hardening for common Supabase linter warnings + Direct Messages RLS recursion.
-- Safe to re-run (idempotent / "if exists" where possible).

create schema if not exists extensions;

-- Move extensions out of public when allowed (fixes "extension_in_public").
do $$
begin
  if exists (select 1 from pg_extension where extname = 'postgis') then
    begin
      execute 'alter extension postgis set schema extensions';
    exception
      when others then null;
    end;
  end if;
end;
$$;

-- Fix "function_search_path_mutable" for notifications_fill_kind (whatever signature exists).
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
      and p.proname = 'notifications_fill_kind'
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

-- Public buckets don't need broad SELECT policies on storage.objects for public URL access.
-- Keeping these policies allows listing all files in the bucket (linter warning).
do $$
begin
  if to_regclass('storage.objects') is not null then
    execute 'drop policy if exists "storage_media_select_public" on storage.objects';
    execute 'drop policy if exists "storage_stories_select_public" on storage.objects';
  end if;
end;
$$;

-- Avoid RLS policy recursion for Direct Messages by using a SECURITY DEFINER helper with
-- row_security disabled, and restrict policies to authenticated/service_role.
do $$
begin
  if to_regclass('public.direct_thread_members') is not null
     and to_regclass('public.direct_threads') is not null then

    execute $fn$
      create or replace function public.is_direct_thread_member(p_thread_id text, p_user_id uuid)
      returns boolean
      language sql
      stable
      security definer
      set search_path = public
      set row_security = off
      as $$
        select exists (
          select 1
          from public.direct_thread_members m
          where m.thread_id = p_thread_id
            and m.user_id = p_user_id
        );
      $$;
    $fn$;

    execute 'revoke all on function public.is_direct_thread_member(text, uuid) from public';
    execute 'grant execute on function public.is_direct_thread_member(text, uuid) to authenticated';
    execute 'grant execute on function public.is_direct_thread_member(text, uuid) to service_role';

    execute 'drop policy if exists "direct_thread_members_select_member" on public.direct_thread_members';
    execute $p$
      create policy "direct_thread_members_select_member"
      on public.direct_thread_members for select
      to authenticated, service_role
      using (
        public.is_direct_thread_member(direct_thread_members.thread_id, auth.uid())
        or coalesce(auth.role(), '') = 'service_role'
      );
    $p$;

    execute 'drop policy if exists "direct_thread_members_update_member_nickname" on public.direct_thread_members';
    execute $p$
      create policy "direct_thread_members_update_member_nickname"
      on public.direct_thread_members for update
      to authenticated, service_role
      using (
        (
          direct_thread_members.user_id = auth.uid()
          and public.is_direct_thread_member(direct_thread_members.thread_id, auth.uid())
        )
        or coalesce(auth.role(), '') = 'service_role'
      )
      with check (
        (
          direct_thread_members.user_id = auth.uid()
          and public.is_direct_thread_member(direct_thread_members.thread_id, auth.uid())
        )
        or coalesce(auth.role(), '') = 'service_role'
      );
    $p$;

    execute 'drop policy if exists "direct_threads_update_member" on public.direct_threads';
    execute $p$
      create policy "direct_threads_update_member"
      on public.direct_threads for update
      to authenticated, service_role
      using (
        public.is_direct_thread_member(direct_threads.id, auth.uid())
        or coalesce(auth.role(), '') = 'service_role'
      )
      with check (
        public.is_direct_thread_member(direct_threads.id, auth.uid())
        or coalesce(auth.role(), '') = 'service_role'
      );
    $p$;
  end if;
end;
$$;

-- These functions are read-only and already protected by RLS, so they don't need SECURITY DEFINER.
do $$
begin
  if to_regprocedure('public.get_content_translation(text,uuid,text,text)') is not null then
    execute 'alter function public.get_content_translation(text, uuid, text, text) security invoker';
  end if;
  if to_regprocedure('public.resolve_app_region(text)') is not null then
    execute 'alter function public.resolve_app_region(text) security invoker';
  end if;
  if to_regprocedure('public.get_enabled_feature_rollouts(uuid)') is not null then
    execute 'alter function public.get_enabled_feature_rollouts(uuid) security invoker';
  end if;
end;
$$;

-- Reduce linter noise: internal SECURITY DEFINER trigger/maintenance functions should not be
-- executable by PUBLIC (and therefore anon/authenticated).
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and (
        p.proname like 'trg\_%' escape '\'
        or p.proname like '%\_trigger' escape '\'
        or p.proname in (
          'ensure_notification_preferences',
          'insert_notification_smart',
          'notifications_sync_read_fields',
          'notifications_unread_count',
          'touch_playlist_updated_at'
        )
      )
  loop
    execute format('revoke execute on function %s from public', r.sig);
  end loop;
end;
$$;

commit;
