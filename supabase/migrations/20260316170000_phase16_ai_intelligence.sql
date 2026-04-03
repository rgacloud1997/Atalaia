begin;

create extension if not exists unaccent;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'ai_urgency_level') then
    create type public.ai_urgency_level as enum ('low', 'medium', 'high', 'critical');
  end if;

  if not exists (select 1 from pg_type where typname = 'ai_category') then
    create type public.ai_category as enum (
      'health',
      'family',
      'finance',
      'relationships',
      'deliverance',
      'mental_health',
      'protection',
      'guidance',
      'gratitude',
      'other'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'ai_entity_type') then
    create type public.ai_entity_type as enum ('post', 'location');
  end if;
end
$$;

create table if not exists public.ai_analysis (
  id uuid primary key default gen_random_uuid(),
  entity_type public.ai_entity_type not null,
  entity_id uuid not null,
  category public.ai_category not null default 'other'::public.ai_category,
  urgency_level public.ai_urgency_level not null default 'low'::public.ai_urgency_level,
  keywords text[] not null default '{}'::text[],
  summary text,
  spam_score integer not null default 0,
  language text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (entity_type, entity_id)
);

create index if not exists idx_ai_analysis_entity on public.ai_analysis (entity_type, entity_id);
create index if not exists idx_ai_analysis_category on public.ai_analysis (category);
create index if not exists idx_ai_analysis_urgency_level on public.ai_analysis (urgency_level);
create index if not exists idx_ai_analysis_keywords_gin on public.ai_analysis using gin (keywords);

drop trigger if exists trg_ai_analysis_updated_at on public.ai_analysis;
create trigger trg_ai_analysis_updated_at
before update on public.ai_analysis
for each row execute function public.set_updated_at();

alter table public.ai_analysis enable row level security;

drop policy if exists "ai_analysis_select_visible" on public.ai_analysis;
create policy "ai_analysis_select_visible"
on public.ai_analysis for select
using (
  (
    entity_type = 'post'::public.ai_entity_type
    and exists (select 1 from public.posts p where p.id = ai_analysis.entity_id)
  )
  or (
    entity_type = 'location'::public.ai_entity_type
    and exists (select 1 from public.locations l where l.id = ai_analysis.entity_id)
  )
);

drop policy if exists "ai_analysis_write_service_only" on public.ai_analysis;
create policy "ai_analysis_write_service_only"
on public.ai_analysis for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create table if not exists public.prayer_heatmap (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id) on delete cascade,
  community_id uuid references public.communities(id) on delete cascade,
  prayer_count integer not null default 0,
  urgency_score integer not null default 0,
  window_hours integer not null default 24,
  updated_at timestamptz not null default now(),
  unique (location_id, community_id, window_hours)
);

create index if not exists idx_prayer_heatmap_updated_at on public.prayer_heatmap (updated_at desc);
create index if not exists idx_prayer_heatmap_location on public.prayer_heatmap (location_id);
create index if not exists idx_prayer_heatmap_community on public.prayer_heatmap (community_id);

alter table public.prayer_heatmap enable row level security;

drop policy if exists "prayer_heatmap_select_all" on public.prayer_heatmap;
create policy "prayer_heatmap_select_all"
on public.prayer_heatmap for select
using (true);

drop policy if exists "prayer_heatmap_write_service_only" on public.prayer_heatmap;
create policy "prayer_heatmap_write_service_only"
on public.prayer_heatmap for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create or replace function public.ai_normalize_text(p_text text)
returns text
language sql
immutable
set search_path = public
as $$
  select lower(unaccent(coalesce(p_text, '')));
$$;

create or replace function public.ai_extract_keywords(p_text text, p_limit integer default 10)
returns text[]
language sql
stable
set search_path = public
as $$
  with raw as (
    select
      regexp_replace(public.ai_normalize_text(p_text), '[^a-z0-9\\s#]+', ' ', 'g') as t
  ),
  tokens as (
    select trim(x) as w
    from raw, regexp_split_to_table(raw.t, '\\s+') as x
  ),
  filtered as (
    select w
    from tokens
    where w is not null
      and w <> ''
      and length(w) >= 3
      and w not in (
        'que','por','para','com','uma','uns','umas','dos','das','aos','nas','nos','ele','ela','eles','elas','isso','isto',
        'essa','esse','esta','este','estao','estão','porque','mais','muito','muita','muitos','muitas','ser','ter','tem',
        'tive','tinha','estou','estamos','estava','estavam','vai','vou','hoje','ontem','amanha','amanhã','favor','peço',
        'peco','orar','oracao','oração','orações','oracoes','pedido','pedidos','senhor','deus','jesus','cristo','amem','amém',
        'minha','meu','meus','minhas','nossa','nosso','nossos','nossas'
      )
  ),
  ranked as (
    select w, count(*) as c
    from filtered
    group by w
    order by c desc, w asc
    limit greatest(coalesce(p_limit, 10), 1)
  )
  select coalesce(array_agg(ranked.w order by ranked.c desc, ranked.w asc), '{}'::text[])
  from ranked;
$$;

create or replace function public.ai_classify_prayer_text(p_text text)
returns table (
  category public.ai_category,
  urgency_level public.ai_urgency_level,
  keywords text[],
  spam_score integer,
  language text
)
language plpgsql
stable
set search_path = public
as $$
declare
  t text;
  has_url boolean;
  repeated boolean;
  len integer;
  score integer := 0;
begin
  t := public.ai_normalize_text(p_text);
  len := length(coalesce(p_text, ''));

  has_url := t ~ '(https?://|www\\.)';
  repeated := t ~ '([a-z0-9])\\1\\1\\1';

  if has_url then score := score + 35; end if;
  if repeated then score := score + 25; end if;
  if len > 900 then score := score + 20; end if;
  if t ~ '(pix|bitcoin|usdt|transferencia|transferência|ganhe\\s+dinheiro|dinheiro\\s+facil|emprestimo|empr[eé]stimo)' then
    score := score + 30;
  end if;
  if t ~ '(porno|porn[oó]|sexo\\s+gratis|aposta|cassino|casino)' then
    score := score + 50;
  end if;

  language := case
    when t ~ '\\b(the|and|please|pray)\\b' then 'en'
    when t ~ '\\b(el|por\\s+favor|orar|oracion|oración)\\b' then 'es'
    else 'pt'
  end;

  category := case
    when t ~ '(c[aá]ncer|doen[cç]a|enferm|febre|dor|hospital|cura|m[eé]dico|sa[uú]de|cirurg)' then 'health'::public.ai_category
    when t ~ '(fam[ií]lia|casamento|marido|esposa|filh|pais|m[ãa]e|pai|lar|div[oó]rcio)' then 'family'::public.ai_category
    when t ~ '(dinheiro|d[ií]vida|divida|emprego|desemprego|trabalho|sal[aá]rio|contas|aluguel|financeiro)' then 'finance'::public.ai_category
    when t ~ '(relacionamento|namoro|amizade|conflito|briga|perd[aã]o|perdao)' then 'relationships'::public.ai_category
    when t ~ '(liberta[cç][aã]o|opress[aã]o|v[ií]cio|vicio|amarra[cç][aã]o|feiti[cç]o|macumba)' then 'deliverance'::public.ai_category
    when t ~ '(depress[aã]o|ansiedade|p[aâ]nico|panico|tristeza|suic[ií]dio|mente|emocional)' then 'mental_health'::public.ai_category
    when t ~ '(prote[cç][aã]o|perigo|amea[cç]a|viol[eê]ncia|acidente|guarda|livramento)' then 'protection'::public.ai_category
    when t ~ '(dire[cç][aã]o|sabedoria|decis[aã]o|prop[oó]sito|vocac[aã]o|discernimento)' then 'guidance'::public.ai_category
    when t ~ '(gratid[aã]o|obrigad|testemunho|vit[oó]ria|milagre)' then 'gratitude'::public.ai_category
    else 'other'::public.ai_category
  end;

  urgency_level := case
    when t ~ '(urgente|agora|hoje|socorro|em\\s+perigo|em\\s+risco|internad|uti|grave|emerg[eê]ncia)' then 'critical'::public.ai_urgency_level
    when t ~ '(desesper|muito\\s+dif[ií]cil|n[aã]o\\s+aguento|piorando|crise)' then 'high'::public.ai_urgency_level
    when t ~ '(preciso|precisamos|passando\\s+por|dificuldade|problema)' then 'medium'::public.ai_urgency_level
    else 'low'::public.ai_urgency_level
  end;

  keywords := public.ai_extract_keywords(p_text, 10);
  spam_score := least(greatest(score, 0), 100);
  return next;
end;
$$;

create or replace function public.ai_translate_text(p_text text, p_target_lang text)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  t text := coalesce(p_text, '');
  lang text := lower(coalesce(p_target_lang, ''));
begin
  if lang not in ('pt', 'en', 'es') then
    return t;
  end if;
  if lang = 'pt' then
    return t;
  end if;

  t := regexp_replace(t, '\\bPeço\\b', case when lang = 'en' then 'I ask' else 'Pido' end, 'g');
  t := regexp_replace(t, '\\bpeço\\b', case when lang = 'en' then 'I ask' else 'pido' end, 'g');
  t := regexp_replace(t, '\\bor[aá]ção\\b', case when lang = 'en' then 'prayer' else 'oración' end, 'gi');
  t := regexp_replace(t, '\\bfam[ií]lia\\b', case when lang = 'en' then 'family' else 'familia' end, 'gi');
  t := regexp_replace(t, '\\bsa[uú]de\\b', case when lang = 'en' then 'health' else 'salud' end, 'gi');
  t := regexp_replace(t, '\\bdoen[cç]a\\b', case when lang = 'en' then 'illness' else 'enfermedad' end, 'gi');
  t := regexp_replace(t, '\\bconflitos?\\b', case when lang = 'en' then 'conflicts' else 'conflictos' end, 'gi');
  t := regexp_replace(t, '\\bpreciso\\b', case when lang = 'en' then 'I need' else 'necesito' end, 'gi');
  t := regexp_replace(t, '\\bprecisamos\\b', case when lang = 'en' then 'we need' else 'necesitamos' end, 'gi');
  return t;
end;
$$;

create or replace function public.ai_upsert_post_analysis(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  p record;
  a record;
  v_has_post_type boolean := false;
  v_is_prayer boolean := false;
  v_spam_reporter uuid;
begin
  select exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'posts'
      and c.column_name = 'post_type'
  )
  into v_has_post_type;

  if v_has_post_type then
    execute
      'select id, body, location_id, community_id, kind, post_type
       from public.posts
       where id = $1
       limit 1'
    into p
    using p_post_id;
    v_is_prayer := coalesce(p.post_type::text, '') = 'prayer';
  else
    execute
      'select id, body, location_id, community_id, kind
       from public.posts
       where id = $1
       limit 1'
    into p
    using p_post_id;
    v_is_prayer := coalesce(p.kind::text, '') = 'request';
  end if;

  if p.id is null then
    return;
  end if;

  if not v_is_prayer then
    delete from public.ai_analysis where entity_type = 'post'::public.ai_entity_type and entity_id = p.id;
    return;
  end if;

  select * into a from public.ai_classify_prayer_text(p.body);

  insert into public.ai_analysis (
    entity_type,
    entity_id,
    category,
    urgency_level,
    keywords,
    spam_score,
    language
  )
  values (
    'post'::public.ai_entity_type,
    p.id,
    a.category,
    a.urgency_level,
    coalesce(a.keywords, '{}'::text[]),
    coalesce(a.spam_score, 0),
    a.language
  )
  on conflict (entity_type, entity_id)
  do update set
    category = excluded.category,
    urgency_level = excluded.urgency_level,
    keywords = excluded.keywords,
    spam_score = excluded.spam_score,
    language = excluded.language,
    updated_at = now();

  if coalesce(a.spam_score, 0) >= 85 then
    v_spam_reporter := public.system_moderator_id();
    if v_spam_reporter is not null then
      insert into public.reports (
        reporter_id,
        entity_type,
        entity_id,
        reason,
        description,
        status
      )
      select
        v_spam_reporter,
        'post'::public.report_target_kind,
        p.id,
        'ai_spam',
        'Detecção automática (AI): spam_score=' || coalesce(a.spam_score, 0)::text,
        'open'::public.report_status
      where not exists (
        select 1
        from public.reports r
        where r.entity_type = 'post'::public.report_target_kind
          and r.entity_id = p.id
          and r.reason = 'ai_spam'
          and r.status = 'open'::public.report_status
      );
    end if;
  end if;
end;
$$;

create or replace function public.trg_ai_analyze_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ai_upsert_post_analysis(new.id);
  return new;
end;
$$;

drop trigger if exists trg_posts_ai_analysis on public.posts;
do $$
declare
  v_has_post_type boolean := false;
begin
  select exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'posts'
      and c.column_name = 'post_type'
  )
  into v_has_post_type;

  if v_has_post_type then
    execute '
      create trigger trg_posts_ai_analysis
      after insert or update of body, post_type, location_id, community_id
      on public.posts
      for each row execute function public.trg_ai_analyze_post();
    ';
  else
    execute '
      create trigger trg_posts_ai_analysis
      after insert or update of body, kind, location_id, community_id
      on public.posts
      for each row execute function public.trg_ai_analyze_post();
    ';
  end if;
end;
$$;

create or replace function public.refresh_prayer_heatmap(
  p_window_hours integer default 24,
  p_community_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cutoff timestamptz;
  v_rows integer := 0;
  v_window integer := 24;
  v_has_post_type boolean := false;
  v_pred text;
  v_sql text;
begin
  v_window := greatest(coalesce(p_window_hours, 24), 1);
  v_cutoff := now() - make_interval(hours => v_window);

  select exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'posts'
      and c.column_name = 'post_type'
  )
  into v_has_post_type;

  v_pred := case
    when v_has_post_type then 'coalesce(p.post_type::text, '''') = ''prayer'''
    else 'coalesce(p.kind::text, '''') = ''request'''
  end;

  v_sql := replace(
    $q$
    with base as (
      select
        p.location_id,
        p.community_id,
        count(*)::int as prayer_count,
        sum(
          case a.urgency_level
            when 'critical'::public.ai_urgency_level then 4
            when 'high'::public.ai_urgency_level then 3
            when 'medium'::public.ai_urgency_level then 2
            else 1
          end
        )::int as urgency_score
      from public.posts p
      left join public.ai_analysis a
        on a.entity_type = 'post'::public.ai_entity_type
       and a.entity_id = p.id
      where __PRED__
        and p.created_at >= $1
        and p.location_id is not null
        and ($2 is null or p.community_id = $2)
      group by p.location_id, p.community_id
    ),
    up as (
      insert into public.prayer_heatmap (
        location_id,
        community_id,
        prayer_count,
        urgency_score,
        window_hours,
        updated_at
      )
      select
        b.location_id,
        case when $2 is null then b.community_id else $2 end,
        b.prayer_count,
        b.urgency_score,
        $3,
        now()
      from base b
      on conflict (location_id, community_id, window_hours)
      do update set
        prayer_count = excluded.prayer_count,
        urgency_score = excluded.urgency_score,
        updated_at = excluded.updated_at
      returning 1
    )
    select count(*) from up
    $q$,
    '__PRED__',
    v_pred
  );

  execute v_sql into v_rows using v_cutoff, p_community_id, v_window;

  delete from public.prayer_heatmap h
  where h.window_hours = v_window
    and (p_community_id is null or h.community_id = p_community_id)
    and h.updated_at < now() - interval '10 minutes';

  return v_rows;
end;
$$;

create or replace function public.prayer_heatmap_for_map(
  p_window_hours integer default 24,
  p_community_id uuid default null,
  p_limit integer default 800
)
returns table (
  location_id uuid,
  center_lat double precision,
  center_lng double precision,
  prayer_count integer,
  urgency_score integer
)
language sql
stable
set search_path = public
as $$
  select
    h.location_id,
    l.center_lat,
    l.center_lng,
    h.prayer_count,
    h.urgency_score
  from public.prayer_heatmap h
  join public.locations l on l.id = h.location_id
  where h.window_hours = greatest(coalesce(p_window_hours, 24), 1)
    and (p_community_id is null or h.community_id = p_community_id)
    and l.center_lat is not null
    and l.center_lng is not null
  order by h.urgency_score desc, h.prayer_count desc, h.updated_at desc
  limit greatest(coalesce(p_limit, 800), 1);
$$;

create or replace function public.ai_region_summary(
  p_location_id uuid,
  p_window_hours integer default 48,
  p_community_id uuid default null
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_cutoff timestamptz;
  v_window integer := 48;
  v_total integer;
  v_top_category text;
  v_second text;
  v_top_keywords text[];
  v_has_post_type boolean := false;
  v_pred text;
  v_sql text;
  v_path text;
begin
  if p_location_id is null then
    return null;
  end if;

  select path into v_path from public.locations where id = p_location_id limit 1;
  if v_path is null then
    return null;
  end if;

  v_window := greatest(coalesce(p_window_hours, 48), 1);
  v_cutoff := now() - make_interval(hours => v_window);

  select exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'posts'
      and c.column_name = 'post_type'
  )
  into v_has_post_type;

  v_pred := case
    when v_has_post_type then 'coalesce(p.post_type::text, '''') = ''prayer'''
    else 'coalesce(p.kind::text, '''') = ''request'''
  end;

  v_sql := replace(
    $q$
    with scope_posts as (
      select p.id
      from public.posts p
      join public.locations l on l.id = p.location_id
      where __PRED__
        and p.created_at >= $1
        and p.location_id is not null
        and ($2 is null or p.community_id = $2)
        and (l.id = $3 or l.path like ($4 || '/%'))
    ),
    cats as (
      select a.category::text as category, count(*)::int as c
      from public.ai_analysis a
      join scope_posts sp on sp.id = a.entity_id
      where a.entity_type = 'post'::public.ai_entity_type
      group by a.category
      order by c desc
      limit 2
    ),
    kw as (
      select unnest(a.keywords) as k
      from public.ai_analysis a
      join scope_posts sp on sp.id = a.entity_id
      where a.entity_type = 'post'::public.ai_entity_type
    ),
    kw_rank as (
      select k, count(*)::int as c
      from kw
      group by k
      order by c desc, k asc
      limit 6
    )
    select
      (select count(*) from scope_posts),
      (select category from cats offset 0),
      (select category from cats offset 1),
      (select coalesce(array_agg(k order by c desc, k asc), '{}'::text[]) from kw_rank)
    $q$,
    '__PRED__',
    v_pred
  );

  execute v_sql
  into v_total, v_top_category, v_second, v_top_keywords
  using v_cutoff, p_community_id, p_location_id, v_path;

  if coalesce(v_total, 0) = 0 then
    return 'Sem volume significativo de pedidos nas últimas ' || v_window::text || 'h.';
  end if;

  return
    'Resumo da região (' || v_total::text || ' pedidos nas últimas ' || v_window::text || 'h): '
    || 'Predominam temas de ' || coalesce(v_top_category, 'outros')
    || case when v_second is not null then ' e ' || v_second else '' end
    || case when array_length(v_top_keywords, 1) is not null and array_length(v_top_keywords, 1) > 0
      then '. Palavras-chave: ' || array_to_string(v_top_keywords, ', ')
      else ''
    end
    || '.';
end;
$$;

create or replace function public.ai_region_themes(
  p_location_id uuid,
  p_window_hours integer default 48,
  p_community_id uuid default null
)
returns table (
  theme text,
  count integer
)
language plpgsql
stable
set search_path = public
as $$
declare
  v_cutoff timestamptz;
  v_window integer := 48;
  v_path text;
  v_has_post_type boolean := false;
  v_pred text;
  v_sql text;
begin
  if p_location_id is null then
    return;
  end if;

  select path into v_path from public.locations where id = p_location_id limit 1;
  if v_path is null then
    return;
  end if;

  v_window := greatest(coalesce(p_window_hours, 48), 1);
  v_cutoff := now() - make_interval(hours => v_window);

  select exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'posts'
      and c.column_name = 'post_type'
  )
  into v_has_post_type;

  v_pred := case
    when v_has_post_type then 'coalesce(p.post_type::text, '''') = ''prayer'''
    else 'coalesce(p.kind::text, '''') = ''request'''
  end;

  v_sql := replace(
    $q$
    with scope_posts as (
      select p.id
      from public.posts p
      join public.locations l on l.id = p.location_id
      where __PRED__
        and p.created_at >= $1
        and ($2 is null or p.community_id = $2)
        and (l.id = $3 or l.path like ($4 || '/%'))
    )
    select a.category::text as theme, count(*)::int as count
    from public.ai_analysis a
    join scope_posts sp on sp.id = a.entity_id
    where a.entity_type = 'post'::public.ai_entity_type
    group by a.category
    order by count desc, theme asc
    limit 8
    $q$,
    '__PRED__',
    v_pred
  );

  return query execute v_sql using v_cutoff, p_community_id, p_location_id, v_path;
end;
$$;

create or replace function public.ai_prayer_suggestions(
  p_location_id uuid,
  p_window_hours integer default 48,
  p_community_id uuid default null
)
returns text[]
language plpgsql
stable
set search_path = public
as $$
declare
  t record;
  out text[] := '{}'::text[];
begin
  for t in
    select theme, count
    from public.ai_region_themes(p_location_id, p_window_hours, p_community_id)
    limit 3
  loop
    out := out || case t.theme
      when 'health' then array['Ore por cura, sabedoria médica e restauração física.']
      when 'family' then array['Ore pela unidade da família, reconciliação e proteção do lar.']
      when 'finance' then array['Ore por provisão, portas abertas e organização financeira.']
      when 'relationships' then array['Ore por perdão, restauração de relacionamentos e paz.']
      when 'deliverance' then array['Ore por libertação, quebra de opressões e fortalecimento espiritual.']
      when 'mental_health' then array['Ore por paz na mente, esperança e alegria renovada.']
      when 'protection' then array['Ore por livramento, proteção e guarda divina.']
      when 'guidance' then array['Ore por direção, discernimento e decisões sábias.']
      when 'gratitude' then array['Ore com gratidão e fortaleça a fé com testemunhos.']
      else array['Ore por misericórdia, consolo e renovo espiritual.']
    end;
  end loop;

  if coalesce(array_length(out, 1), 0) = 0 then
    out := array[
      'Ore por consolo e fortalecimento.',
      'Ore por proteção espiritual.',
      'Ore por sabedoria e direção.'
    ];
  end if;

  return out;
end;
$$;

create or replace function public.ai_create_prayer_challenges_from_hotspots(
  p_window_hours integer default 24,
  p_min_count integer default 25,
  p_days integer default 7,
  p_community_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_created integer := 0;
  r record;
  v_title text;
  v_desc text;
begin
  perform public.refresh_prayer_heatmap(p_window_hours, p_community_id);

  for r in
    select
      h.location_id,
      h.prayer_count,
      l.name as location_name
    from public.prayer_heatmap h
    join public.locations l on l.id = h.location_id
    where h.window_hours = greatest(coalesce(p_window_hours, 24), 1)
      and (p_community_id is null or h.community_id = p_community_id)
      and h.prayer_count >= greatest(coalesce(p_min_count, 25), 1)
    order by h.urgency_score desc, h.prayer_count desc
    limit 10
  loop
    v_title := 'Intercessão por ' || coalesce(r.location_name, 'região');
    v_desc := 'Movimento gerado automaticamente a partir de alto volume de pedidos nas últimas '
      || greatest(coalesce(p_window_hours, 24), 1)::text || 'h.';

    insert into public.prayer_challenges (
      title,
      description,
      target_region,
      target_location_id,
      community_id,
      goal_participants,
      goal_prayer_minutes,
      start_date,
      end_date,
      status
    )
    select
      v_title,
      v_desc,
      'world',
      r.location_id,
      p_community_id,
      100,
      7,
      (now() at time zone 'utc')::timestamptz,
      ((now() at time zone 'utc') + make_interval(days => greatest(coalesce(p_days, 7), 1)))::timestamptz,
      'draft'::public.prayer_challenge_status
    where not exists (
      select 1
      from public.prayer_challenges ch
      where ch.target_location_id = r.location_id
        and ch.community_id is not distinct from p_community_id
        and ch.created_at > now() - interval '7 days'
    );

    if found then
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;

grant execute on function public.prayer_heatmap_for_map(integer, uuid, integer) to anon, authenticated;
grant execute on function public.ai_region_summary(uuid, integer, uuid) to anon, authenticated;
grant execute on function public.ai_region_themes(uuid, integer, uuid) to anon, authenticated;
grant execute on function public.ai_prayer_suggestions(uuid, integer, uuid) to anon, authenticated;
grant execute on function public.ai_translate_text(text, text) to anon, authenticated;

commit;
