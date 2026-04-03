begin;

alter table public.stories
  alter column city_id drop not null;

alter table public.stories
  alter column media_type set default 'image';

alter table public.stories
  add column if not exists community_id uuid references public.communities(id) on delete set null;

alter table public.stories
  add column if not exists state_id uuid references public.locations(id) on delete set null;

alter table public.stories
  add column if not exists region_path text;

alter table public.stories
  add column if not exists audience_type text not null default 'social';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'stories_audience_type_check'
      and conrelid = 'public.stories'::regclass
  ) then
    alter table public.stories
      add constraint stories_audience_type_check
      check (audience_type in ('social', 'community', 'regional'));
  end if;
end
$$;

create index if not exists idx_stories_audience_expires_at
  on public.stories (audience_type, expires_at desc);

create index if not exists idx_stories_community_expires_at
  on public.stories (community_id, expires_at desc);

commit;
