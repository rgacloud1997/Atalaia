begin;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'notification_kind'
  ) then
    return;
  end if;

  alter type public.notification_kind add value if not exists 'post_new';
  alter type public.notification_kind add value if not exists 'story_new';
  alter type public.notification_kind add value if not exists 'alert_new';
  alter type public.notification_kind add value if not exists 'prayer_request';
  alter type public.notification_kind add value if not exists 'comment';
  alter type public.notification_kind add value if not exists 'reaction';
  alter type public.notification_kind add value if not exists 'follow';
  alter type public.notification_kind add value if not exists 'scale_reminder_24h';
  alter type public.notification_kind add value if not exists 'scale_reminder_1h';
  alter type public.notification_kind add value if not exists 'challenge_milestone';
  alter type public.notification_kind add value if not exists 'challenge_reminder';
end;
$$;

alter table public.notifications
  alter column kind drop not null;

commit;
