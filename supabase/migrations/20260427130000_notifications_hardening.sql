begin;

alter table public.notifications
  add column if not exists is_read boolean not null default false,
  add column if not exists read_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

-- Backfill/coherence for existing data (safe no-op when already consistent).
update public.notifications
set is_read = (read_at is not null)
where is_read is distinct from (read_at is not null);

create or replace function public.notifications_sync_read_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- If any client writes read_at, keep is_read in sync.
  if new.read_at is not null then
    new.is_read := true;
  end if;

  -- If any client writes is_read, keep read_at in sync.
  if new.is_read and new.read_at is null then
    new.read_at := now();
  elsif (not new.is_read) and new.read_at is not null then
    new.read_at := null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notifications_sync_read_fields on public.notifications;
create trigger trg_notifications_sync_read_fields
before insert or update on public.notifications
for each row execute function public.notifications_sync_read_fields();

drop trigger if exists trg_notifications_updated_at on public.notifications;
create trigger trg_notifications_updated_at
before update on public.notifications
for each row execute function public.set_updated_at();

create or replace function public.notifications_unread_count(p_user_id uuid default null)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_target uuid;
  v_count integer;
begin
  v_uid := auth.uid();
  v_target := coalesce(p_user_id, v_uid);
  if v_uid is null or v_target is null or v_target <> v_uid then
    return 0;
  end if;

  select count(*)::int
  into v_count
  from public.notifications n
  where n.user_id = v_target
    and n.is_read = false;

  return coalesce(v_count, 0);
end;
$$;

commit;
