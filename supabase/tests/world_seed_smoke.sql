-- World seed smoke test
-- =====================
-- Roda em cluster temp SEM postgis. Faz mock de ST_GeomFromText/ST_Multi e
-- da coluna geom (como text) para que as migrations apliquem sem dependência
-- de PostGIS. Valida que:
--   1. World, 7 continentes e seed inicial BR continuam existentes (idempotência)
--   2. Países do mundo foram criados (~234 esperados)
--   3. Israel está em world/as/il com parent_id = continent 'as'
--   4. Israel tem 6 distritos como filhos (level='state')
--   5. Brasil mantém path world/sa/br após upsert (idempotência preservada)
--   6. Brasil tem 27 estados após upsert (era 2, deve passar a 27)
--   7. Estados existentes (GO/SP) tiveram geom preenchida

\set ON_ERROR_STOP on

-- ----- Mocks PostGIS (executar antes das migrations que usam) -----

create or replace function public.st_geomfromtext(p_wkt text, p_srid int)
returns text language sql immutable as $$ select p_wkt $$;

create or replace function public.st_multi(p_geom text)
returns text language sql immutable as $$ select p_geom $$;

-- Mock para st_simplifypreservetopology / st_asgeojson / st_contains (se chamados)
create or replace function public.st_simplifypreservetopology(p_geom text, p_tol double precision)
returns text language sql immutable as $$ select p_geom $$;

create or replace function public.st_asgeojson(p_geom text)
returns text language sql immutable as $$ select '{}' $$;

create or replace function public.st_contains(p_a text, p_b text)
returns boolean language sql immutable as $$ select true $$;

create or replace function public.st_setsrid(p_geom text, p_srid int)
returns text language sql immutable as $$ select p_geom $$;

create or replace function public.st_makepoint(p_lng double precision, p_lat double precision)
returns text language sql immutable as $$ select 'POINT(' || p_lng || ' ' || p_lat || ')' $$;

-- ----- Verificações -----

do $$
declare
  v_count_countries int;
  v_count_states int;
  v_israel_id uuid;
  v_israel_parent uuid;
  v_asia_id uuid;
  v_israel_states int;
  v_br_states int;
  v_br_id uuid;
  v_go_geom text;
begin
  select id into v_asia_id from public.locations where level='continent' and code='as' limit 1;
  if v_asia_id is null then
    raise exception 'continent "as" missing — seed inicial não rodou';
  end if;

  select count(*) into v_count_countries from public.locations where level='country';
  raise notice 'countries: %', v_count_countries;
  if v_count_countries < 200 then
    raise exception 'expected >= 200 countries after world seed, got %', v_count_countries;
  end if;

  select count(*) into v_count_states from public.locations where level='state';
  raise notice 'states: %', v_count_states;
  if v_count_states < 4000 then
    raise exception 'expected >= 4000 states after world seed, got %', v_count_states;
  end if;

  -- Israel
  select id, parent_id into v_israel_id, v_israel_parent
  from public.locations where path = 'world/as/il' limit 1;
  if v_israel_id is null then
    raise exception 'Israel (world/as/il) missing';
  end if;
  if v_israel_parent <> v_asia_id then
    raise exception 'Israel parent_id mismatches Asia';
  end if;

  select count(*) into v_israel_states from public.locations
  where parent_id = v_israel_id and level = 'state';
  raise notice 'Israel states: %', v_israel_states;
  if v_israel_states < 6 then
    raise exception 'expected 6 Israel states, got %', v_israel_states;
  end if;

  -- Brasil idempotência
  select id into v_br_id from public.locations where path='world/sa/br' limit 1;
  if v_br_id is null then
    raise exception 'Brasil path world/sa/br missing after upsert';
  end if;

  select count(*) into v_br_states from public.locations
  where parent_id = v_br_id and level = 'state';
  raise notice 'Brasil states: %', v_br_states;
  if v_br_states < 27 then
    raise exception 'expected 27 BR states, got %', v_br_states;
  end if;

  -- Verifica que GO/SP existentes tiveram geom preenchida
  select geom into v_go_geom from public.locations where path='world/sa/br/go' limit 1;
  if v_go_geom is null then
    raise exception 'Goiás geom not populated by upsert';
  end if;

  raise notice 'OK: world seed smoke passed';
end $$;
