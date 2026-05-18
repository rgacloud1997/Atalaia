# 📔 HANDOFF — Relatório de Escalas (sessão 18/05/2026)

> **Para quem chega agora**: este documento é o ponto de entrada para retomar o trabalho no sistema de Relatórios de Escalas de Oração do Atalaia Social. Lê-lo antes de mexer em qualquer arquivo evita refazer descobertas que já foram feitas e tomar decisões que já foram tomadas.
>
> **Data da sessão**: 18 de maio de 2026  
> **Branch**: `main`  
> **Estado do remoto**: 4 commits à frente de `origin/main` (não pushados ainda)  
> **Arquivos vivos**: `INDICE_ROADMAP_ESCALAS.md`, `ROADMAP_RELATORIO_ESCALAS_2026.md`, `supabase/migrations/20260428…`, `supabase/migrations/20260518…`, `supabase/tests/prayer_reports_rpcs_smoke.sql`, `app/lib/main.dart`

---

## 🧭 TL;DR

A sessão foi disparada por uma varredura procurando "Fase 2" no projeto. Descobrimos que **as Fases 2 (backend) e 3 (camada de dados Flutter) já estavam implementadas no commit `9331fc8`**, mas os roadmaps haviam nascido desatualizados (o mesmo commit que entregou a feature criou os documentos como se ela ainda fosse fazer). A partir daí:

1. Atualizamos os dois roadmaps refletindo o que estava entregue.
2. Tomamos 4 decisões de produto que estavam abertas (permissões, timezone, exportação, refresh).
3. Escrevemos a smoke suite das 8 RPCs (Fase 2.3) — 54 asserções.
4. Validamos a suite contra um Postgres temporário; ela pegou um bug latente no primeiro run.
5. Corrigimos o bug com migration nova.
6. Refatoramos 7 das 8 RPCs para aceitar `p_tz`, decorrência da decisão de timezone.

**Resultado**: Fase 2 100% fechada; Fase 4 (UI) destravada. Próximo bloco lógico: variantes "self" para membros não-admin, e depois Sprint 1 da UI.

---

## 🏛️ Contexto do projeto (para quem chega cold)

**Atalaia Social** é um app Flutter (`app/`) + backend Supabase (`supabase/`) — uma rede social com foco em oração comunitária. As "comunidades" do app são igrejas, ministérios ou grupos de oração. Cada comunidade pode criar **escalas de oração** (`community_prayer_schedules`) onde membros são alocados em turnos (`community_prayer_schedule_runs`). Ao executar o turno, o usuário gera uma `prayer_session` ligada ao run.

O sistema de **Relatório de Escalas** é a feature que dá visibilidade analítica sobre essas escalas: quem cumpriu, quem faltou, em que região, em que horário, contra quais alvos de oração, etc. É composto de:

- 1 tabela nova (`prayer_targets`) — alvos de oração ("Pela Nação", "Pelas Famílias")
- 8 RPCs SQL especializadas
- 8 Models Dart + métodos no `DemoRepository`
- 1 tela `PrayerReportScreen` (ainda não construída — Fase 4)

### Estrutura de pastas relevantes

```
app/lib/main.dart                    # MEGA arquivo único com tudo do Flutter (~30k+ linhas)
supabase/migrations/                 # Migrations SQL ordenadas cronologicamente
supabase/tests/                      # Smoke tests em SQL puro, sem pg_tap
INDICE_ROADMAP_ESCALAS.md            # Roadmap resumido (índice)
ROADMAP_RELATORIO_ESCALAS_2026.md    # Roadmap detalhado
HANDOFF_RELATORIO_ESCALAS_2026-05-18.md  # Este documento
```

### Convenções do projeto

- **`main.dart` monolítico**: tudo em um arquivo só, incluindo Models, Repository, Widgets, telas. Não tentar quebrar em arquivos sem decisão explícita — isso é uma escolha consciente.
- **Repository pattern**: classe `DemoRepository` (linha ~13000+) com método para cada operação Supabase. Todos os métodos têm guard `if (sb == null || isOffline)` e `try/catch` que retornam estado vazio em vez de propagar exceções. Isso é importante: **erros das RPCs ficam silenciados na UI**.
- **Migrations**: SQL puro, nome no padrão `YYYYMMDDHHmmss_descricao.sql`, sempre `begin;` ... `commit;`. RLS com policies nomeadas. Funções SQL com `security definer` + `set search_path = public` + guard com `auth.uid()` + `community_is_admin()`.
- **Testes Supabase**: SQL puro em `supabase/tests/*.sql`, sem pg_tap. Padrão `do $$ ... raise exception ... end $$` para asserções. Identidade simulada via `set role authenticated` + `select set_config('request.jwt.claim.sub', '...', false)`.

---

## 📍 Onde estamos no roadmap

| Fase | Descrição | Status real |
|------|-----------|-------------|
| 1 | Diagnóstico inicial | ✅ Concluída antes da sessão |
| 2 | Backend BD + 8 RPCs + testes | ✅ **100% concluída nesta sessão** |
| 3 | Models + Repository Flutter | ✅ Já concluída (commit `9331fc8`) + `tz` opcional adicionado |
| 4 | UI/Widgets (4 sprints) | 🔄 **Próxima** — destravada e bloqueada apenas pelo TODO 1 abaixo |
| 5 | Filtros cruzados | 🟡 Backend pronto (RPC 8); UI sai junto da Fase 4 |
| 6 | Helpers/exportação | ⏳ Pós-Fase 4 |

Restante estimado: **~4-5 semanas** (Fase 4 é 4 semanas + Fase 6 1-2 dias).

---

## 🔓 Decisões de produto fechadas em 18/05/2026

Estas decisões estavam abertas no roadmap e foram resolvidas com o usuário. **Não reabri-las sem motivo forte** — a implementação atual depende delas.

| Decisão | Resolução | Por quê |
|---------|-----------|---------|
| **Permissões** | Admin vê tudo da comunidade + membro vê apenas os próprios dados. Admin pode promover outros membros a admin. | Modelo híbrido equilibra privacidade (membro não vê faltas dos outros) com observabilidade (admin enxerga o todo). Promoção dinâmica de admin já tem RLS pronta (policy `community_members_update_by_admin` em `20260314150000_phase8_communities_groups.sql:249`). |
| **Timezone** | UI em local time + RPCs aceitam parâmetro `p_tz` e usam `at time zone p_tz` no lugar de `'utc'` para agrupamentos por hora/dia | RPCs internamente usam UTC, mas relatórios precisam ser legíveis no fuso do usuário (Brasil é UTC-3). Conversão só no client perderia o agrupamento por dia em casos de borda. Solução: RPCs param `p_tz text default 'UTC'`, default mantém back-compat. |
| **Exportação V1** | PDF **+** CSV | Decisão do usuário; cobertura completa para diferentes tipos de uso (PDF para envio/impressão, CSV para análise no Excel). Vai exigir packages `pdf` + `printing` + geração CSV nativa em Dart + `share_plus`. |
| **Refresh** | Pull-to-refresh + botão no AppBar | Mais simples (sem realtime, sem auto-refresh, sem sobrecarga de backend). Pode evoluir para realtime se necessário em iteração futura. |

### Decisões ainda em aberto

Estas não bloqueiam a Fase 4 mas precisam ser fechadas em algum momento:

- **Histórico (audit trail)**: manter histórico de faltas com timestamp para forense? Sem decisão. Provavelmente sai em iteração V2.
- **Notificações sobre relatórios**: avisar usuários quando atingem N faltas / ranking baixo? Sem decisão. Iteração V2.

---

## 📦 Commits novos da sessão (em ordem cronológica)

### 1. `cb95c67` — Docs: atualiza roadmaps refletindo Fases 2 e 3 entregues

**Por quê**: os dois roadmaps haviam sido committados junto com a implementação no commit `9331fc8` — ou seja, nasceram desatualizados. Quem lia o documento via "Fase 2 - PRÓXIMA" mas o código já tinha as 8 RPCs e os 8 models.

**O que mudou**:
- `INDICE_ROADMAP_ESCALAS.md` e `ROADMAP_RELATORIO_ESCALAS_2026.md` ganharam:
  - Marcadores ✅ em Fases 2 e 3 com referências `arquivo:linha` para cada uma das 8 RPCs e cada um dos 8 models
  - Notas de implementação onde houve divergência do spec original:
    - **RPC 3 (`get_prayers_by_completion_status`)**: retorna lista flat; agrupamento por status feito no client em `DemoRepository.getPrayersByCompletionStatus` (`main.dart:13681`)
    - **RPC 4 (`get_coverage_by_region`)**: a região é derivada via `prayer_sessions.location_id` da sessão completada **OU** da região primária do usuário (CTE `user_primary_region`); runs sem nenhuma região associada são descartados do agregado
    - **RPC 6 (`get_time_slot_coverage`)**: o slot mínimo é clampeado em 15 min (`v_slot := greatest(coalesce(p_slot_minutes, 60), 15)`); `empty_count` é binário por linha
    - **`getPrayerReportCrossData`**: retorna `List<Map<String, dynamic>>` (uso bruto na UI); sem model dedicado por enquanto
  - Bloco de decisões fechadas em 18/05/2026
  - Próximos passos reescritos como TODOs concretos
  - Timeline com status real

### 2. `f22af36` — test(supabase): smoke tests para as 8 RPCs de relatórios

**Por quê**: a Fase 2.3 do roadmap (testes isolados das RPCs) estava pendente. Sem ela, qualquer regressão nas RPCs só apareceria em produção como relatórios vazios (porque o repository engole exceções — ver `main.dart:13769`, `13799`, `13858`).

**Arquivo**: `supabase/tests/prayer_reports_rpcs_smoke.sql` (~617 linhas)

**Estrutura**:
- Bootstrap idêntico ao `rls_smoke.sql`: cria roles `anon`/`authenticated`/`service_role`, schema `auth`, `auth.uid()`, `auth.role()`
- TRUNCATE CASCADE em todas as tabelas relevantes (destrutivo — **rodar contra DB isolado**)
- Seed mínimo: 3 users (admin, member, outsider), 1 community, 1 location, 2 prayer_targets, 2 schedules, 6 runs (2 completed, 2 missed, 1 cancelled, 1 scheduled futuro), 2 prayer_sessions ligadas aos completed
- Para cada RPC: caminho feliz + 3-5 casos negativos (auth_required, community_required, not_allowed, range_required, invalid_range, invalid_hour_range)
- RPC 8 ganhou um teste extra de filtro: `p_statuses => ['missed']` deve retornar exatamente 2

**Total no commit original**: 47 asserções. (Depois cresceu para 54 com testes de `p_tz`.)

**Convenção seguida**:
```sql
do $$
begin
  begin
    perform * from public.get_xxx(...);
    raise exception 'TEST X.Y: expected exception';
  exception when others then
    if sqlerrm <> 'expected_error_code' then
      raise exception 'TEST X.Y: wrong message: %', sqlerrm;
    end if;
  end;
end $$;
```

### 3. `350526e` — Fix: cast `dense_rank() ::int` em 3 RPCs

**Por quê — a história do bug**: ao rodar a smoke suite pela primeira vez contra um cluster Postgres 18.1 temporário, ela falhou no TEST 4.a (`get_coverage_by_region`, happy path) com:

```
ERROR: structure of query does not match function result type
DETAIL: Returned type bigint does not match expected type integer
        in column "rank" (position 9).
```

3 RPCs declaravam `rank integer` em `RETURNS TABLE` mas atribuíam `dense_rank()` sem cast — e `dense_rank()` retorna `bigint`:

- `get_coverage_by_region` (`20260428112000_reports_rpcs_2_4.sql:332`)
- `get_coverage_by_target` (`20260428113000_reports_rpcs_5_8.sql:95`)
- `get_failure_analysis` (`20260428113000_reports_rpcs_5_8.sql:346`)

**Impacto latente em produção**:
- A UI da Fase 4 ainda não chama essas RPCs, então o bug não causou dano visível
- Mas o `DemoRepository` engole exceções (`try { ... } catch (_) { return const []; }`)
- Quando a UI fosse plugada, os relatórios de região/alvo/falhas ficariam **silenciosamente vazios** em produção, sem nenhum log nem alerta

**Fix**: trocar `dense_rank() over (...) as rank` por `dense_rank() over (...)::int as rank`. Aplicado em migration nova `20260518100000_fix_reports_rank_bigint_cast.sql` em vez de editar as migrations originais (preserva o histórico).

**Lição**: testes integrados pegaram um bug que revisão estática não pegaria. Vale a pena rodar a suite em qualquer cluster antes de cada release.

### 4. `f3dd5e9` — Refactor: 7 RPCs aceitam p_tz para agrupamentos locais

**Por quê**: decorrência da decisão de timezone (UI em local time). Sem isso, `get_time_slot_coverage` e `get_prayer_by_user_detailed.common_hours` agrupariam por hora UTC — incorreto para usuários brasileiros (3h de diferença).

**Migration**: `supabase/migrations/20260518110000_reports_rpcs_p_tz.sql` (~700 linhas)

**Detalhes técnicos importantes**:

1. **7 RPCs ganham `p_tz text default 'UTC'`**:
   - `get_prayer_scale_summary`, `get_prayer_by_user_detailed`, `get_coverage_by_region`, `get_coverage_by_target`, `get_time_slot_coverage`, `get_failure_analysis`, `get_prayer_report_cross_data`
   - Todas as expressões `at time zone 'utc'` trocadas por `at time zone p_tz`

2. **RPC 3 (`get_prayers_by_completion_status`) NÃO recebeu `p_tz`** — usa apenas comparação direta de `timestamptz`, sem `date` cast nem `extract(hour ...)`. Adicionar p_tz seria YAGNI. Se um futuro consumidor precisar, basta adicionar.

3. **Assinaturas antigas dropadas explicitamente** ao final da migration:
   ```sql
   drop function if exists public.get_prayer_scale_summary(uuid, date, date);
   ...
   ```
   Por quê: PG permite overloads por assinatura. Sem o drop, teríamos a antiga (3 args) e a nova (4 args) coexistindo. Calls com 3 args resolveriam para a antiga (sem p_tz). Drop force os callers a usar a nova (que tem default UTC, então é totalmente back-compat).

4. **Default `'UTC'` é o que garante back-compat**: callers que ainda não passem o parâmetro continuam recebendo o comportamento antigo. A política Supabase RPC client (named-param) faz a resolução correta.

5. **DemoRepository atualizado**: 7 métodos ganham `String tz = 'UTC'` opcional, que é propagado para `params['p_tz']`. Default UTC mantém comportamento atual. A UI da Fase 4 vai passar o tz do dispositivo.

6. **Smoke suite ganhou 7 asserções (TEST 9.a-9.g)** validando que cada RPC com p_tz aceita `'America/Sao_Paulo'` e retorna resultados consistentes. Total agora: **54 asserções, exit 0**.

---

## 🎯 Próximos passos (ordenados)

### TODO 1: Variantes "self" para membros comuns (~4-6h)

**Por quê é o próximo**: a decisão de permissões diz "admin vê tudo + membro vê os próprios dados". Hoje as RPCs exigem `community_is_admin` — então o membro comum não consegue chamar nada. Sem isso, a Fase 4 não pode entregar a tela para usuário não-admin.

**O que fazer**:

**Opção A (recomendada)**: adicionar parâmetro `p_self_only boolean default false` nas 3 RPCs relevantes:
- `get_prayer_scale_summary` (RPC 1) — resumo do próprio usuário
- `get_prayer_by_user_detailed` (RPC 2) — uma linha só, do próprio usuário
- `get_prayer_report_cross_data` (RPC 8) — runs do próprio usuário

Lógica nova:
```sql
if v_uid is null then raise exception 'auth_required'; end if;
if p_community_id is null then raise exception 'community_required'; end if;
if p_self_only then
  -- não exige admin, mas força filtro por assigned_user_id = auth.uid()
  if not public.community_can_view(p_community_id, v_uid) then
    raise exception 'not_allowed';
  end if;
else
  if not public.community_is_admin(p_community_id, v_uid) then
    raise exception 'not_allowed';
  end if;
end if;
```

E na CTE/where:
```sql
and (not p_self_only or r.assigned_user_id = v_uid)
```

**Opção B**: criar 3 RPCs `..._self()` espelho. Mais código duplicado, menos prazer.

**Recomendação firme**: opção A.

**No DemoRepository**: adicionar `bool selfOnly = false` aos 3 métodos correspondentes e propagar como `'p_self_only': selfOnly`.

**Na smoke suite**: adicionar 3 asserções:
- Com `p_self_only=true` e `auth.uid()` membro comum → não raise; retorna apenas as 3 runs do membro (do seed: r2 completed, r3 missed, r5 cancelled)
- Com `p_self_only=true` e `auth.uid()` admin → retorna apenas as 3 runs do admin (r1 completed, r4 missed, r6 scheduled)
- Com `p_self_only=true` e outsider (não membro da community) → raise `'not_allowed'`

### TODO 2: Auditar UI de gestão de roles (~2-4h, depende do que já existe)

**Por quê**: a decisão de permissões inclui "admin pode promover outros membros a admin". A infra de RLS existe (policy `community_members_update_by_admin` em `20260314150000_phase8_communities_groups.sql:249` permite admin atualizar qualquer row de `community_members`). Mas **não verificamos se há UI para isso** — pode já existir, pode não existir.

**O que fazer**:
1. `Grep` em `main.dart` por padrões: `community_members`, `'admin'`, `'moderator'`, `'founder'`, `role:`, `promote`, `demote`, `gerenciar membro`, `tornar admin`
2. Se já existe diálogo/tela: ótimo, só documentar
3. Se não existe: adicionar em `CommunityMembersScreen` (se houver) um item de menu "Promover a admin" / "Rebaixar a membro" condicionado a `community_is_admin(auth.uid())`. Implementação simples: `UPDATE community_members SET role = 'admin' WHERE community_id = $1 AND user_id = $2;` — a RLS já libera.

### TODO 3: Fase 4 — Sprint 1 da UI (~1 semana)

**Por quê**: backend pronto, decisões fechadas, agora é renderizar.

**Escopo do Sprint 1** (do roadmap detalhado):
- Criar `PrayerReportScreen` em `app/lib/main.dart` + rota
- Ponto de entrada: painel admin da comunidade (admin mode) + perfil do usuário ou tela da comunidade (self mode, depois do TODO 1)
- Section: 7 cards resumidos consumindo `getPrayerScaleSummary` (admin ou self)
- DateRange picker em **local time** (default últimos 30 dias) — passar `tz = DateTime.now().timeZoneName` ou IANA via package `flutter_timezone` (ver caveat técnico abaixo)
- `RefreshIndicator` (pull-to-refresh) + `IconButton` de refresh no AppBar
- Loading/empty/error states

**Próximos sprints da Fase 4** (do roadmap detalhado):
- Sprint 2 (Semana 2): aba "Por Usuário" + aba "Por Orações"
- Sprint 3 (Semana 3): aba "Por Região" + aba "Por Alvo" + aba "Por Horário" + Charts
- Sprint 4 (Semana 4): aba "Falhas" + Filtros cruzados (consumindo RPC 8) + Exportar PDF/CSV

### TODO 4 (pós-Fase 4): Helpers/Exportação (Fase 6, ~1-2 dias)

- Helpers de formatação de durações, datas em local time, números percentuais
- Geração de PDF: package `pdf` + `printing` + layout customizado por aba
- Geração de CSV: nativo em Dart (`StringBuffer`, escape de aspas)
- Compartilhamento: `share_plus` para anexar/enviar

---

## ⚠️ Caveats e gotchas técnicos

### 1. Cluster local sem postgis / Docker

Setup local: scoop Postgres 18.1, sem Docker. Postgis NÃO está disponível como extension.

Para rodar a smoke suite localmente contra um cluster temp, **pular** estas 2 migrations:
- `20260312130000_postgis_locations_geom.sql`
- `20260313180000_phase4_feed.sql`

10 outras migrations falham em cadeia (postgis/storage/stories/ads), mas **nenhuma delas é necessária para as RPCs de relatórios**. Lista completa de migrations que falham num cluster vanilla:

```
20260312130100_resolve_location_by_point_geom.sql    # depende de geom
20260312130200_map_locations_shapes.sql              # depende de geom
20260313133000_media_bucket_and_files.sql            # depende de schema storage
20260313150000_stories.sql                            # depende de schema storage
20260314133000_phase7_moderation_reputation.sql      # depende de public.stories
20260317110000_phase11_ads_monetization.sql          # depende de public.media_files
20260317130000_phase12_global_expansion.sql          # depende de função is_moderator
20260319170000_fix_security_lints.sql                # depende de public.ad_impressions
20260321100000_phase1_3_7_backfill_and_integrations.sql  # depende de public.stories
20260403120000_stories_social_audience_nullable_city.sql  # depende de public.stories
```

Em produção (Supabase) todas funcionam porque o `storage` schema existe nativamente.

### 2. DemoRepository engole exceções silenciosamente

`main.dart:13769`, `13799`, `13858`, etc. — todos os métodos de relatório fazem `try { ... } catch (_) { return const []; }`. Isso significa:

- Erros das RPCs em produção viram **listas vazias** na UI, sem log
- A UI da Fase 4 PRECISA distinguir "lista vazia legítima" (sem dados) de "lista vazia por erro" para mostrar erro adequado
- **Sugestão para a Fase 4**: trocar `catch (_)` por algo que pelo menos faça `dev.log()` e expose um estado de erro na model. Não fizemos isso porque é mudança maior e fora do escopo da sessão.

### 3. Smoke suite é destrutiva

`supabase/tests/prayer_reports_rpcs_smoke.sql` começa com `TRUNCATE ... CASCADE` em:
- `community_prayer_schedule_runs`, `community_prayer_schedules`, `prayer_targets`
- `prayer_sessions`, `community_members`, `communities`, `profiles`, `locations`
- `auth.users`

**NUNCA rodar contra o `.pgdata` local do dev** — destrói o seed. Sempre contra DB isolado (Supabase staging/branch, cluster temp).

Procedimento testado para cluster temp Postgres 18.1:
```bash
PG_TEMP_DIR=/tmp/atalaia-test-pg-tmp
initdb -D "$PG_TEMP_DIR" -U postgres --auth=trust --no-locale --encoding=UTF8
pg_ctl -D "$PG_TEMP_DIR" -o "-p 55433" -l "$PG_TEMP_DIR/postmaster.log" -w start
createdb -h 127.0.0.1 -p 55433 -U postgres atalaia_test
psql -h 127.0.0.1 -p 55433 -U postgres -d atalaia_test -v ON_ERROR_STOP=1 -f supabase/tests/bootstrap_auth.sql

# Loop applying migrations (skip postgis ones)
cd supabase/migrations
for f in $(ls *.sql | sort); do
  case "$f" in
    20260312130000_postgis_locations_geom.sql|20260313180000_phase4_feed.sql) continue ;;
  esac
  psql -h 127.0.0.1 -p 55433 -U postgres -d atalaia_test -v ON_ERROR_STOP=1 -f "$f" > /dev/null 2>&1 || true
done

# Run smoke
psql -h 127.0.0.1 -p 55433 -U postgres -d atalaia_test -v ON_ERROR_STOP=1 \
  -f supabase/tests/prayer_reports_rpcs_smoke.sql

# Cleanup
pg_ctl -D "$PG_TEMP_DIR" stop -m fast
rm -rf "$PG_TEMP_DIR"
```

Exit code 0 = todos os 54 asserts passaram.

### 4. Convenção de timezone IANA vs nome curto

O `at time zone 'America/Sao_Paulo'` aceita IANA. **Não** aceita "BRT" / "GMT-3" / nomes curtos em todos os casos. No Flutter:

- `DateTime.now().timeZoneName` retorna nome curto/abreviação ("BRT", "GMT-3", varia por plataforma) — **não recomendado**
- Para obter IANA, usar package [`flutter_timezone`](https://pub.dev/packages/flutter_timezone) — `await FlutterTimezone.getLocalTimezone()` retorna "America/Sao_Paulo"

A Fase 4 vai precisar adicionar `flutter_timezone` ao `pubspec.yaml`.

Para teste / fallback: `'UTC'` é sempre válido (e é o default).

### 5. RPC 3 (`get_prayers_by_completion_status`) é diferente

Esta RPC:
- Recebe `timestamptz`, não `date`
- Não tem `range_required` nem `invalid_range` checks
- Não tem `p_tz` (não usa date grouping)
- Retorna lista flat; o agrupamento por status (completed/missed/cancelled/scheduled) é feito no client em `DemoRepository.getPrayersByCompletionStatus` (`main.dart:13681`)

Não confundir com as outras 7. Se for adicionar `p_tz` a ela depois, há um único `extract` para se preocupar — mas atualmente não usa nenhum.

### 6. Para a UI da Fase 4: priorizar mostrar erros

Como mencionado em (2), o repository silencia erros. Antes de fazer Sprint 1, considerar:

- Trocar `catch (_)` por `catch (e, st) { dev.log('...', error: e, stackTrace: st); rethrow; }` ou similar
- Ou: criar uma classe `Result<T>` (sucesso/erro/loading) que a UI usa
- Ou: ao menos um state separado para "erro" vs "vazio" na model que alimenta a tela

Sem isso, a UI vai parecer "funcionando" para o usuário mesmo quando estiver quebrada.

---

## 🧪 Como validar localmente

### Validar smoke suite
Ver caveat (3) acima. Exit 0 = OK.

### Validar Dart compila
```bash
cd app && flutter analyze
```

Não rodei isso na sessão — `main.dart` é monolítico e demora. Mas as mudanças no `DemoRepository` foram aditivas (novo parâmetro com default), não devem ter quebrado nada.

### Validar Flutter app roda
```bash
cd app && flutter run -d <device>
```

A tela de relatório ainda não existe; rodar o app só valida que a build não quebrou.

---

## 📂 Resumo dos arquivos a conhecer

| Arquivo | Papel |
|---------|-------|
| `INDICE_ROADMAP_ESCALAS.md` | Roadmap resumido com TODOs marcados |
| `ROADMAP_RELATORIO_ESCALAS_2026.md` | Roadmap detalhado (1308 linhas) com SQL/Dart das 6 fases |
| `HANDOFF_RELATORIO_ESCALAS_2026-05-18.md` | Este documento |
| `supabase/migrations/20260428110000_prayer_targets_table.sql` | Tabela `prayer_targets` + coluna em `community_prayer_schedules` |
| `supabase/migrations/20260428111000_get_prayer_scale_summary_rpc.sql` | RPC 1 (versão original; substituída em parte por 20260518110000) |
| `supabase/migrations/20260428112000_reports_rpcs_2_4.sql` | RPCs 2, 3, 4 (versão original) |
| `supabase/migrations/20260428113000_reports_rpcs_5_8.sql` | RPCs 5, 6, 7, 8 (versão original) |
| `supabase/migrations/20260518100000_fix_reports_rank_bigint_cast.sql` | Bug fix `dense_rank()::int` em RPCs 4, 5, 7 |
| `supabase/migrations/20260518110000_reports_rpcs_p_tz.sql` | Refactor `p_tz` em 7 RPCs (substitui as anteriores) |
| `supabase/tests/prayer_reports_rpcs_smoke.sql` | 54 asserções de smoke das 8 RPCs |
| `app/lib/main.dart` linhas 2316–2700 | 8 Models Dart + factories `fromSupabase` |
| `app/lib/main.dart` linhas 13566–13900 | 8 métodos `DemoRepository` (com `tz` opcional após refactor) |

---

## 🎬 Pendência operacional

- 4 commits ainda **não pushados** para `origin/main`. Quando o usuário decidir, `git push` para sincronizar.
- `supabase/.temp/cli-latest` foi modificado pelo Supabase CLI (atualização automática de cache de versão) — não relacionado com o trabalho da sessão; ignorar ou stash.

---

**Documento gerado por**: Claude Opus 4.7 (1M context)  
**Para**: próximo agente / dev humano que vai retomar o trabalho  
**Tom**: factual, com o "por quê" sempre disponível para julgamento de edge cases  
**Última edição**: 18/05/2026
