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

### 🔄 Fase 2: Backend DB + RPCs (4-5 dias) - **PRÓXIMA**

**Tarefas**:

1. **2.1 - Criar Tabela `prayer_targets`** (1 dia)
   - Campos: id, community_id, title, description, target_type, is_active, etc.
   - Índices e RLS policies
   - Migração SQL: `20260428_prayer_targets_table.sql`

2. **2.2 - Implementar 8 RPC Functions** (4 dias)
   ```
   ✓ get_prayer_scale_summary()           [Dashboard geral]
   ✓ get_prayer_by_user_detailed()        [Por usuário]
   ✓ get_prayers_by_completion_status()   [Por orações]
   ✓ get_coverage_by_region()             [Por região]
   ✓ get_coverage_by_target()             [Por alvo]
   ✓ get_time_slot_coverage()             [Por horário]
   ✓ get_failure_analysis()               [Falhas]
   ✓ get_prayer_report_cross_data()       [Genérica com filtros]
   ```

3. **2.3 - Testar RPCs Isoladamente** (1 dia)

---

### 📦 Fase 3: Modelos Flutter + Repository (2-3 dias)

**Tarefas**:

1. **3.1 - Criar Models Dart** (1-2 dias)
   - `PrayerScaleSummaryModel`
   - `UserPrayerStatsModel`
   - `PrayerByCompletionModel` + `PrayerRunDetailModel`
   - `RegionCoverageModel`
   - `TargetCoverageModel` + `UserResponsibilityModel`
   - `TimeSlotCoverageModel`
   - `FailureAnalysisModel`
   - `PrayerFilterOptions`

2. **3.2 - Estender DemoRepository** (1 dia)
   - 8 novos métodos (um para cada RPC)
   - Desserialização e erro handling

---

### 🎨 Fase 4: UI/Widgets (4 semanas)

**Sprint 1** (Semana 1): Dashboard + Cards + Filtros básicos  
**Sprint 2** (Semana 2): Por Usuário + Por Orações  
**Sprint 3** (Semana 3): Por Região + Por Alvo + Por Horário + Charts  
**Sprint 4** (Semana 4): Falhas + Filtros + Exportar  

---

### 🔀 Fase 5: Filtros Cruzados (2-3 dias, paralelo com Fase 4)

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

## 🚀 PRÓXIMOS PASSOS (HOJE/AMANHÃ)

### ✅ TODO 1: Criar Migration - Prayer Targets
- [ ] Criar arquivo: `supabase/migrations/20260428_prayer_targets_table.sql`
- [ ] Adicionar coluna `prayer_target_id` em `community_prayer_schedules`
- [ ] Deploy ao Supabase

**Tempo**: ~1 hora

---

### ✅ TODO 2: Implementar 1ª RPC - Scale Summary
- [ ] Criar função SQL `get_prayer_scale_summary()`
- [ ] Testar com dados reais
- [ ] Validar retorno

**Tempo**: ~4 horas

---

### ✅ TODO 3: Implementar Restantes 7 RPCs
- [ ] Criar as 7 funções restantes
- [ ] Testar cada uma isoladamente
- [ ] Documentar parâmetros e retornos

**Tempo**: ~16 horas (spread 3-4 dias)

---

### ✅ TODO 4: Criar Models Dart
- [ ] Copiar código dos 8 models do roadmap para `main.dart`
- [ ] Adicionar factories para desserializar
- [ ] Testar compilação

**Tempo**: ~4 horas

---

### ✅ TODO 5: Estender Repository
- [ ] Adicionar 8 novos métodos ao `DemoRepository`
- [ ] Implementar error handling
- [ ] Testar conexão com Supabase

**Tempo**: ~4 horas

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
| Fase 2: Backend | 4-5 dias | 🔄 Próxima |
| Fase 3: Models | 2-3 dias | ⏳ Aguardando |
| Fase 4: UI | 4 semanas | ⏳ Aguardando |
| Fase 5: Filtros | 2-3 dias (paralelo) | ⏳ Aguardando |
| Fase 6: Helpers | 1-2 dias | ⏳ Aguardando |
| **TOTAL** | **5-6 semanas** | |

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

**Última atualização**: 28 de abril de 2026  
**Status**: Pronto para implementação  
**Próximo Check-in**: Após conclusão Fase 2

---

## 📁 ARQUIVOS ASSOCIADOS

- `ROADMAP_RELATORIO_ESCALAS_2026.md` - Documento completo
- `supabase/migrations/20260428_prayer_targets_table.sql` - (A ser criado)
- `supabase/migrations/20260428_prayer_report_functions.sql` - (A ser criado)
- `app/lib/main.dart` - (A ser editado com Models + Repo)

