-- Verificacao rapida do schema para sincronizacao do Direct
-- Rode apos aplicar a migration 20260427120000_direct_thread_settings_sync.sql

select table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in ('direct_threads', 'direct_thread_members')
  and column_name in ('theme_key', 'ephemeral_hours', 'nickname')
order by table_name, column_name;

select conname, pg_get_constraintdef(c.oid) as definition
from pg_constraint c
join pg_namespace n on n.oid = c.connamespace
where n.nspname = 'public'
  and conrelid in ('public.direct_threads'::regclass, 'public.direct_thread_members'::regclass)
  and conname in ('direct_threads_ephemeral_hours_check', 'direct_thread_members_nickname_len_check')
order by conname;

select policyname, tablename, permissive, roles, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('direct_threads', 'direct_thread_members')
  and policyname in (
    'direct_threads_update_member',
    'direct_thread_members_select_member',
    'direct_thread_members_update_member_nickname'
  )
order by tablename, policyname;
