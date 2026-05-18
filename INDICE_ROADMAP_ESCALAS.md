# 📚 ÍNDICE COMPLETO - ROADMAP ESCALAS DE ORAÇÃO

## 📖 Documentos Criados

### 1. **ROADMAP_RELATORIO_ESCALAS_2026.md** 
   Arquivo principal com toda a estratégia de implementação
   
   **Conteúdo**:
   - Sumário Executivo
   - 6 Fases de Implementação
   - Timeline Consolidada
   - Próximos Passos Imediatos
   - 8 RPCs SQL Detalhadas
   - Código Dart dos Models
   - Extensão do Repository
   - Estrutura de UI (7 abas)
   - 4 Sprints de Desenvolvimento
   - Boas Práticas
   - Perguntas de Decisão

   **Tamanho**: ~100 KB | **Duração leitura**: ~20 min

---

## 🎯 FASES RESUMIDAS

### ✅ Fase 1: Diagnóstico (CONCLUÍDA)

**O que foi feito**:
- Exploração completa da estrutura Flutter/Supabase
- Mapeamento de tabelas, modelos e localizações existentes
- Identificação de 1 gap principal: Sem "Alvos de Oração"
- Status geral: 30% infra, 0% UI

---

### ✅ Fase 2: Backend DB + RPCs — **CONCLUÍDA** (commit `9331fc8`)

**Tarefas entregues**:

1. **2.1 - Tabela `prayer_targets`** ✅
   - Migration: `supabase/migrations/20260428110000_prayer_targets_table.sql`
   - Inclui RLS, índices, trigger `updated_at`, coluna `prayer_target_id` em `community_prayer_schedules` + índice

2. **2.2 - 8 RPC Functions** ✅
   ```
   ✅ get_prayer_scale_summary()         → 20260428111000_get_prayer_scale_summary_rpc.sql
   ✅ get_prayer_by_user_detailed()      → 20260428112000_reports_rpcs_2_4.sql:3
   ✅ get_prayers_by_completion_status() → 20260428112000_reports_rpcs_2_4.sql:164
   ✅ get_coverage_by_region()           → 20260428112000_reports_rpcs_2_4.sql:236
   ✅ get_coverage_by_target()           → 20260428113000_reports_rpcs_5_8.sql:3
   ✅ get_time_slot_coverage()           → 20260428113000_reports_rpcs_5_8.sql:116
   ✅ get_failure_analysis()             → 20260428113000_reports_rpcs_5_8.sql:207
   ✅ get_prayer_report_cross_data()     → 20260428113000_reports_rpcs_5_8.sql:369
   ```
   Todas com `security definer`, `community_is_admin()` enforcement, validação de range e `grant execute ... to authenticated`.

3. **2.3 - Testes isolados das RPCs** ⏳ **PENDENTE**
   - Nenhum arquivo dedicado em `supabase/tests/` (existem só `rls_smoke.sql`, `direct_thread_settings_sync_check.sql`, `bootstrap_auth.sql`).

---

### ✅ Fase 3: Modelos Flutter + Repository — **CONCLUÍDA** (commit `9331fc8`)

**Tarefas entregues**:

1. **3.1 - Models Dart em `app/lib/main.dart`** ✅
   - `PrayerScaleSummaryModel` (linha 2316)
   - `UserPrayerStatsModel` (linha 2354)
   - `PrayerByCompletionModel` + `PrayerRunDetailModel`
   - `RegionCoverageModel` (linha 2476)
   - `TargetCoverageModel` + responsáveis em JSONB (linha 2534)
   - `TimeSlotCoverageModel` (linha 2592)
   - `FailureAnalysisModel` (linha 2630)
   - `PrayerFilterOptions` (linha 2671)

2. **3.2 - DemoRepository (8 métodos)** ✅ (`app/lib/main.dart:13566–13900`)
   - `getPrayerScaleSummary`, `getUserPrayerStats`, `getPrayersByCompletionStatus`, `getRegionCoverage`, `getTargetCoverage`, `getTimeSlotCoverage`, `getFailureAnalysis`, `getPrayerReportCrossData`
   - Todos com guard offline/sem-supabase e try/catch retornando estado vazio

---

### 🎨 Fase 4: UI/Widgets (4 semanas) — **PRÓXIMA**

**Sprint 1** (Semana 1): Dashboard + Cards + Filtros básicos  
**Sprint 2** (Semana 2): Por Usuário + Por Orações  
**Sprint 3** (Semana 3): Por Região + Por Alvo + Por Horário + Charts  
**Sprint 4** (Semana 4): Falhas + Filtros + Exportar  

---

### 🔀 Fase 5: Filtros Cruzados — **Backend já pronto**, falta UI (2-3 dias, paralelo com Fase 4)

> RPC `get_prayer_report_cross_data` + classe `PrayerFilterOptions` + método `DemoRepository.getPrayerReportCrossData` já implementados na Fase 2/3. Resta a UI de seleção de filtros + chamada na tela.


**Exemplo de uso**:
```dart
final filters = PrayerFilterOptions(
  fromDate: DateTime(2026, 5, 1),
  toDate: DateTime(2026, 5, 31),
  statuses: ['missed'],
  targetIds: ['nacao-target-id'],
  hourStart: 19,
  hourEnd: 22,
);

var results = await repo.getPrayerReportCrossData('community-id', filters);
```

---

### 🏗️ Fase 6: Helpers + Reutilização (1-2 dias)

- Funções helper para formatação, exportação, agrupamento
- Padrões reutilizáveis para futuros relatórios

---

## 📊 7 ABAS DE RELATÓRIOS

| # | Nome | Objetivo | Dados Principais |
|---|------|----------|------------------|
| 1 | 📊 Dashboard | Visão geral | Cards + Gráficos |
| 2 | 👤 Por Usuário | Performance individual | Lista com detalhe |
| 3 | 🙏 Por Orações | Status de cumprimento | Agrupado por status |
| 4 | 🗺️ Por Região | Cobertura espiritual | Tabela com % |
| 5 | 🎯 Por Alvo | Orações por target | Tabela + Responsáveis |
| 6 | 🕐 Por Horário | Cobertura de slots | Grid de horários |
| 7 | ⚠️ Análise de Falhas | Ranking de ausências | Top faltosos + análise |

---

## 💾 ESTRUTURA DE BANCO DE DADOS

### Tabelas Existentes
- `community_prayer_schedules` - Escalas criadas
- `community_prayer_schedule_runs` - Turnos/execuções
- `prayer_sessions` - Sessões realizadas
- `communities` - Comunidades
- `profiles` - Usuários
- `community_members` - Membros

### Tabelas Novas (Fase 2)
- `prayer_targets` - Alvos de oração

### Alterações
- Adicionar coluna `prayer_target_id` em `community_prayer_schedules`

---

## 📱 ESTRUTURA DE UI PROPOSTA

```
PrayerReportScreen
├─ AppBar: "Relatório de Escalas"
├─ Section: CARDS RESUMIDOS (7 cards)
├─ Section: FILTROS COMBINÁVEIS
│  ├─ DateRange selector
│  ├─ Dropdowns: Comunidade, Região, Usuário, Alvo, Status, Horário, Dia
│  └─ Buttons: "Limpar Filtros", "Aplicar"
├─ Section: GRÁFICOS
│  ├─ Bar Chart (distribuição)
│  ├─ Pie Chart (cumprimento %)
│  └─ Line Chart (trend)
├─ TabBar: 7 abas
│  └─ TabBarView: Conteúdo específico
└─ BottomBar: "Exportar PDF", "Exportar CSV", "Atualizado às HH:MM"
```

---

## 🚀 PRÓXIMOS PASSOS

> Fases 2 e 3 entregues no commit `9331fc8`. Os TODOs abaixo refletem o que sobrou para destravar a Fase 4 (UI).

### ✅ Concluído
- [x] Migration `prayer_targets` + coluna em `community_prayer_schedules`
- [x] 8 RPCs SQL implementadas com RLS via `community_is_admin`
- [x] 8 Models Dart + factories `fromSupabase`
- [x] 8 métodos no `DemoRepository` com guard offline

---

### ⏳ TODO 1: Testar RPCs Isoladamente (Fase 2.3)
- [ ] Criar `supabase/tests/prayer_reports_rpcs_smoke.sql` cobrindo:
  - Sucesso básico de cada uma das 8 RPCs com dados de seed
  - Negativo: `auth_required`, `not_allowed` (não-admin), `invalid_range`, `community_required`
- [ ] Rodar localmente via `supabase test db` antes do próximo deploy

**Tempo estimado**: ~4-6 horas

---

### ✅ Decisões fechadas (18/05/2026)

| Decisão | Resolução |
|---------|-----------|
| **Permissões** | Admin vê tudo da comunidade + membro vê os próprios dados. Admin pode promover outros membros a admin (a infra de RLS já existe: policy `community_members_update_by_admin` em `20260314150000_phase8_communities_groups.sql:249`). |
| **Timezone** | UI em local time + adicionar parâmetro `p_tz` às RPCs e usar `at time zone p_tz` no lugar de `'utc'` para agrupamentos por hora/dia. Requer **migration de refactor**. |
| **Exportação V1** | PDF **+** CSV. PDF via package `pdf` + `printing`; CSV nativo em Dart. |
| **Refresh** | Pull-to-refresh + botão no AppBar. Sem realtime nem auto-refresh por enquanto. |

---

### ⏳ TODO 2: Refactor RPCs para `p_tz` (decorrência da decisão de timezone)
- [ ] Nova migration `20260518xxxxxx_reports_rpcs_tz.sql` que substitui as 8 RPCs adicionando `p_tz text default 'UTC'`
- [ ] Trocar todas as expressões `at time zone 'utc'` por `at time zone p_tz`
- [ ] Atualizar `DemoRepository` para passar o tz do dispositivo (ex.: `DateTime.now().timeZoneName` ou IANA via package `flutter_timezone`)
- [ ] Cobrir nos testes da Fase 2.3

**Tempo estimado**: ~3-4 horas

---

### ⏳ TODO 3: Adicionar variantes "self" para membros comuns
Como a decisão é "membro vê os próprios dados", precisamos de uma forma de o membro consultar **apenas o que é dele** sem ser admin:

**Opção A (recomendada)**: adicionar parâmetro `p_self_only boolean default false` nas RPCs relevantes (1, 2, 8) que, quando true, dispensa o check de admin mas força `assigned_user_id = auth.uid()` no `where`.

**Opção B**: criar 3 RPCs `..._self()` espelho.

- [ ] Decidir A vs B
- [ ] Migration
- [ ] Atualizar Repository (`getPrayerScaleSummary({selfOnly: false})` etc.)

**Tempo estimado**: ~4-6 horas

---

### ⏳ TODO 4: Iniciar Fase 4 — Sprint 1 da UI
- [ ] Criar `PrayerReportScreen` em `app/lib/main.dart` + rota
- [ ] Ponto de entrada: painel admin da comunidade (já existe). Membro acessa a partir do seu perfil/comunidade vendo apenas a versão "self".
- [ ] Section: 7 cards resumidos consumindo `getPrayerScaleSummary`
- [ ] DateRange picker (default últimos 30 dias) com timezone local
- [ ] RefreshIndicator (pull-to-refresh) + IconButton no AppBar
- [ ] Loading/empty/error states

**Tempo estimado**: 1 semana (Sprint 1 conforme roadmap principal)

---

### ⏳ TODO 5: Telas de gestão de admins (decorrência da decisão de permissões)
A infra de RLS já permite a ação (`community_members_update_by_admin`), mas a UI provavelmente não tem o botão.

- [ ] Verificar se já existe tela de "membros da comunidade" com gestão de roles em `main.dart`
- [ ] Se não: adicionar diálogo "Promover a admin" / "Rebaixar a membro" no perfil do membro dentro da comunidade

**Tempo estimado**: ~4-6 horas (depende de quanto já existe)

---

## 🔗 LIGAÇÕES ENTRE COMPONENTES

```
Flutter UI
    ↓
PrayerReportScreen
    ↓
Models (8 classes)
    ↓
DemoRepository (8 métodos)
    ↓
Supabase Client
    ↓
RPC Functions (8 functions)
    ↓
SQL Queries
    ↓
Database Tables (7 tables)
```

---

## 📊 DADOS DE EXEMPLO

### Dashboard Cards
```
Total de Escalas: 24
Total de Turnos: 156
Orações Cumpridas: 142 (91%)
Orações Não Cumpridas: 14 (9%)
Usuários Participantes: 18
Tempo Total de Oração: 254h 30m
```

### Por Usuário (Top 3)
```
1. João
   Turnos: 28 | Cumpridos: 28 (100%) | Avg: 1h 15m

2. Maria
   Turnos: 22 | Cumpridos: 19 (86%) | Avg: 1h 20m

3. Pedro
   Turnos: 19 | Cumpridos: 17 (89%) | Avg: 1h 10m
```

### Por Região
```
🥇 Brasília: 45 turnos | 43 cumpridos (96%)
🥈 São Paulo: 38 turnos | 34 cumpridos (89%)
🥉 Rio de Janeiro: 32 turnos | 28 cumpridos (88%)
```

### Análise de Falhas (Top Faltosos)
```
1. Lucas (6 faltas - 30%)
   - Alvos descobertos: Pela Nação
   - Regiões: Sul
   - Horários: 19:00-21:00

2. Ana (4 faltas - 20%)
   - Alvos descobertos: Pelas Famílias
   - Regiões: Norte
   - Horários: 14:00-16:00
```

---

## 🎁 EXTENSÕES FUTURAS (Pós-MVP)

1. **Alertas Automáticos** - Notificar se cumprimento < 70%
2. **Comparação de Períodos** - Mês passado vs. atual
3. **Previsões IA** - Quem fará falta baseado em padrões
4. **Agenda Interativa** - Reatribuir turnos com drag-drop
5. **Integração WhatsApp** - Enviar relatório em PDF
6. **Gamificação** - Badges e rankings
7. **Templates Personalizados** - Salvar filtros como templates

---

## 🔐 PERMISSÕES & RLS

| Role | Pode Ver |
|------|----------|
| Admin Comunitário | Todos os relatórios da comunidade |
| Membro | Apenas seus próprios dados |
| Service Role | Tudo (para seed/automation) |

---

## 💡 BOAS PRÁTICAS

1. ✅ Testar cada RPC isoladamente
2. ✅ Mockar dados para desenvolver UI sem backend
3. ✅ Usar paginação em listas grandes (50-100)
4. ✅ Cachear resultados por 5-10 minutos
5. ✅ Adicionar loading states
6. ✅ Tratar erros gracefully
7. ✅ Usar localizações (PT/EN/ES)
8. ✅ Testar com dados reais antes de deploy

---

## 📞 PERGUNTAS PENDENTES

Antes de iniciar Fase 2, confirme com o time:

1. **Permissões**: Apenas admin vê todos os dados?
2. **Histórico**: Manter audit trail de faltas?
3. **Notificações**: Avisar usuários sobre seus dados?
4. **Exportação**: Prioridade - PDF, CSV ou ambos?
5. **Timezone**: Como lidar com fusos diferentes?
6. **Realtime**: Atualizar gráficos em tempo real?

---

## 📈 ESTIMATIVAS

| Fase | Duração | Status |
|------|---------|--------|
| Fase 1: Diagnóstico | 1 dia | ✅ Concluída |
| Fase 2: Backend (8 RPCs + tabela) | 4-5 dias | ✅ Concluída (commit `9331fc8`); falta só 2.3 (testes isolados) |
| Fase 3: Models + Repository | 2-3 dias | ✅ Concluída (commit `9331fc8`) |
| Fase 4: UI | 4 semanas | 🔄 **Próxima** |
| Fase 5: Filtros cruzados | 2-3 dias (paralelo) | 🟡 Backend pronto; UI pendente |
| Fase 6: Helpers | 1-2 dias | ⏳ Aguardando |
| **RESTANTE** | **~4-5 semanas** | |

---

## 🎯 MÉTRICAS DE SUCESSO

- ✅ 8 RPCs SQL implementadas e testadas
- ✅ 8 Models Dart criados
- ✅ 7 Abas funcionando
- ✅ Filtros cruzados operacionais
- ✅ 90%+ de cobertura de testes
- ✅ Exportação PDF/CSV funcionando
- ✅ Localização PT/EN/ES completa

---

## 📞 CONTATO & SUPORTE

**Dúvidas sobre a implementação**:
- Verificar roadmap completo em `ROADMAP_RELATORIO_ESCALAS_2026.md`
- Consultar exemplos SQL nas 8 RPCs
- Revisar código Dart dos Models

**Alterações**:
- Atualizar este índice
- Revisar dependências de fases

---

**Última atualização**: 18 de maio de 2026 (revisão pós-implementação Fase 2/3)  
**Status**: Backend + camada de dados Flutter concluídos. Próximo passo: testes isolados das RPCs + decisões pendentes + Sprint 1 da UI.  
**Próximo Check-in**: Após Sprint 1 da Fase 4 (cards resumidos no app)

---

## 📁 ARQUIVOS ASSOCIADOS

- `ROADMAP_RELATORIO_ESCALAS_2026.md` - Documento completo
- `supabase/migrations/20260428_prayer_targets_table.sql` - (A ser criado)
- `supabase/migrations/20260428_prayer_report_functions.sql` - (A ser criado)
- `app/lib/main.dart` - (A ser editado com Models + Repo)

