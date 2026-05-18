-- Relaxa a constraint de unicidade de locations.code.
-- =====================================================
-- Antes: UNIQUE (level, code) — exigia que 'go' (Goiás-BR) e 'go' (Goiana-XX)
-- nunca coexistissem globalmente para o mesmo level. Isso bloqueia o seed
-- mundial: vários países usam sufixos iso_3166_2 idênticos (ex.: 'd' em
-- IL-D, EG-D, ...), e a Califórnia (US-CA) colidiria com Cantal (FR-CA).
--
-- Depois: UNIQUE (level, parent_id, code) — escopo natural por pai.
--   • Goiás continua sendo 'go' dentro de Brasil (parent_id=BR.id).
--   • Distrito Sul de Israel pode ser 'd' dentro de Israel.
--   • Estados que compartilham nomes ficam isolados por pais distintos.
--
-- Promove também o UNIQUE de `path` (era um índice parcial WHERE path is not null,
-- que não é aceito como alvo de ON CONFLICT (path)). O world seed depende de
-- UPSERT por path, então a constraint precisa ser uma UNIQUE CONSTRAINT real.
--
-- Aplicação: idempotente (DROP IF EXISTS antes do CREATE).

begin;

alter table public.locations
  drop constraint if exists locations_code_unique;

alter table public.locations
  drop constraint if exists locations_level_parent_code_unique;

alter table public.locations
  add constraint locations_level_parent_code_unique
  unique (level, parent_id, code);

-- path: troca índice parcial por constraint UNIQUE
drop index if exists public.locations_path_unique;
alter table public.locations
  drop constraint if exists locations_path_unique;
alter table public.locations
  add constraint locations_path_unique unique (path);

commit;
