# 📊 ROADMAP: Sistema de Relatórios Cruzados - Escalas de Oração

**Projeto**: Atalaia Social  
**Data**: 28 de abril de 2026  
**Responsável**: Arquitetura de Dados e UI  
**Objetivo**: Implementar sistema completo de análise cruzada de escalas de oração com filtros dinâmicos

---

## 📋 SUMÁRIO EXECUTIVO

### Situação Atual ✅
- **Banco de Dados**: 2 tabelas principais criadas (`community_prayer_schedules`, `community_prayer_schedule_runs`)
- **Backend RPC**: 2 funções básicas implementadas (`get_community_prayer_dashboard`, `get_community_schedule_report`)
- **Flutter**: Models mapeados, Repository pronto, localizações em 3 idiomas
- **Status**: ~30% da infra, 0% da UI

### O Que Falta ❌
- **Tabelas**: Sem "Alvos de Oração" (prayer_targets) - precisamos adicionar
- **RPCs**: Faltam 6 funções especializadas para cada tipo de relatório
- **Flutter Models**: Nenhum modelo de relatório criado ainda
- **UI**: Tela de relatório não existe - precisa ser criada do zero

### Impacto da Proposta ✨
- Solução **escalável** para futuros relatórios
- Filtros **combináveis dinamicamente** (como você pediu)
- **Reutilizável** em outras features (campanhas, eventos, etc)

---

## 🎯 FASES DE IMPLEMENTAÇÃO

### FASE 1: Diagnóstico ✅ CONCLUÍDA

| Item | Status | Achados |
|------|--------|---------|
| **Database Schema** | ✅ | Tabelas mapeadas, 1 gap: sem "alvos de oração" |
| **Backend RPC** | ⚠️ Partial | 2 funções existe, 6 faltam |
| **Flutter Models** | ⚠️ Partial | `_UpcomingAssignedPrayerRun` existe, relatório vazio |
| **Repository** | ✅ | `DemoRepository` pronto para extensão |
| **UI/Screens** | ❌ | Tab "Relatório" não implementada |
| **Localizações** | ✅ | Strings PT/EN/ES já existem |

**Conclusão**: Fundação existe, precisa de extensão significativa na BD e UI zero.

---

### FASE 2: Schema Database + Backend (⏱️ 4-5 dias)

#### 2.1 Adicionar Tabela: Prayer Targets 🎯

```sql
-- Criar tabela de alvos de oração
CREATE TABLE IF NOT EXISTS public.prayer_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  title TEXT NOT NULL,              -- "Pela Nação", "Pelas Famílias"
  description TEXT,
  target_type TEXT NOT NULL DEFAULT 'general',  -- 'nation', 'region', 'group', 'person'
  icon_emoji TEXT,                  -- Para UI
  color_hex TEXT,                   -- Para UI
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT prayer_targets_type_check CHECK (target_type IN ('nation', 'region', 'group', 'person', 'general'))
);

-- Adicionar índices
CREATE INDEX idx_prayer_targets_community_active ON public.prayer_targets (community_id, is_active);

-- RLS
ALTER TABLE public.prayer_targets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "prayer_targets_select_members" ON public.prayer_targets FOR SELECT
USING (public.community_can_view(community_id, auth.uid()) OR coalesce(auth.role(), '') = 'service_role');
CREATE POLICY "prayer_targets_write_admin" ON public.prayer_targets FOR ALL
USING (public.community_is_admin(community_id, auth.uid()) OR coalesce(auth.role(), '') = 'service_role')
WITH CHECK (public.community_is_admin(community_id, auth.uid()) OR coalesce(auth.role(), '') = 'service_role');

-- Ligar escalas com alvos
ALTER TABLE public.community_prayer_schedules
ADD COLUMN IF NOT EXISTS prayer_target_id UUID REFERENCES public.prayer_targets(id) ON DELETE SET NULL;

-- Trigger para updated_at
CREATE TRIGGER IF NOT EXISTS trg_prayer_targets_updated_at
BEFORE UPDATE ON public.prayer_targets
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

**Esforço**: 1 dia  
**Complexidade**: Média  

---

#### 2.2 Criar 8 RPC Functions Especializadas 🔧

##### RPC 1: `get_prayer_scale_summary()`
```sql
FUNCTION: get_prayer_scale_summary(p_community_id UUID, p_from DATE, p_to DATE)
RETURNS: 
  - total_scales: INT              -- Total de escalas criadas
  - total_runs: INT                -- Total de turnos/runs
  - total_completed: INT           -- Turnos cumpridos
  - total_missed: INT              -- Turnos não cumpridos
  - total_cancelled: INT           -- Turnos cancelados
  - completion_rate: FLOAT         -- % de cumprimento
  - unique_users: INT              -- Quantos usuários participaram
  - total_seconds: BIGINT          -- Duração total de oração
  - total_minutes: INT             -- Equivalente em minutos
  - avg_session_duration: INT      -- Duração média de sessão
```

**Propósito**: Cards resumidos do dashboard  
**Esforço**: 1 dia

---

##### RPC 2: `get_prayer_by_user_detailed()`
```sql
FUNCTION: get_prayer_by_user_detailed(p_community_id UUID, p_from DATE, p_to DATE)
RETURNS TABLE:
  - user_id: UUID
  - user_name: TEXT
  - user_avatar_url: TEXT (optional)
  - turns_assigned: INT
  - turns_completed: INT
  - turns_missed: INT
  - turns_cancelled: INT
  - completion_percentage: FLOAT
  - avg_duration_minutes: INT
  - last_completed_at: TIMESTAMPTZ
  - last_assigned_at: TIMESTAMPTZ
  - pending_runs_count: INT        -- Turnos ainda agendados
  - common_hours: JSONB            -- ['19:00', '20:00', ...] (top 3 horários)
  - streak_days: INT               -- Dias consecutivos sem faltar
```

**Propósito**: Tab "Por Usuário"  
**Esforço**: 1.5 dias

---

##### RPC 3: `get_prayers_by_completion_status()`
```sql
FUNCTION: get_prayers_by_completion_status(
  p_community_id UUID, 
  p_from TIMESTAMPTZ, 
  p_to TIMESTAMPTZ,
  p_limit INT DEFAULT 200,
  p_offset INT DEFAULT 0
)
RETURNS TABLE:
  -- Agrupado em: Completadas, Não Cumpridas, Canceladas, Agendadas
  - run_id: UUID
  - status: TEXT
  - scheduled_at: TIMESTAMPTZ
  - actual_at: TIMESTAMPTZ (null se não realizado)
  - target_name: TEXT              -- "Pela Nação"
  - community_name: TEXT
  - user_name: TEXT                -- Responsável
  - planned_duration: INT (minutes)
  - actual_duration: INT (minutes, null se não realizado)
  - notes: TEXT
```

**Propósito**: Tab "Por Orações" com agrupamento  
**Esforço**: 1.5 dias

---

##### RPC 4: `get_coverage_by_region()`
```sql
FUNCTION: get_coverage_by_region(
  p_community_id UUID,
  p_from DATE,
  p_to DATE
)
RETURNS TABLE:
  - region_id: UUID
  - region_name: TEXT
  - total_runs: INT
  - completed_runs: INT
  - missed_runs: INT
  - coverage_percentage: FLOAT
  - unique_users: INT
  - avg_duration: INT (minutes)
  - rank: INT                      -- 1=mais orada, N=menos orada
```

**Propósito**: Tab "Por Região"  
**Esforço**: 1.5 dias

---

##### RPC 5: `get_coverage_by_target()`
```sql
FUNCTION: get_coverage_by_target(
  p_community_id UUID,
  p_from DATE,
  p_to DATE
)
RETURNS TABLE:
  - target_id: UUID
  - target_name: TEXT              -- "Pela Nação"
  - target_emoji: TEXT
  - total_runs: INT
  - completed_runs: INT
  - missed_runs: INT
  - coverage_percentage: FLOAT
  - unique_users: INT              -- Quantos responsáveis diferentes
  - rank: INT                      -- 1=mais orada, N=menos orada
  - responsible_users_json: JSONB  -- [{ id, name, count }]
```

**Propósito**: Tab "Por Alvo de Oração"  
**Esforço**: 1.5 dias

---

##### RPC 6: `get_time_slot_coverage()`
```sql
FUNCTION: get_time_slot_coverage(
  p_community_id UUID,
  p_from DATE,
  p_to DATE,
  p_slot_minutes INT DEFAULT 60  -- Intervalo de agrupamento
)
RETURNS TABLE:
  - time_slot: TEXT                -- "07:00-08:00", "Manhã (06-12h)", etc
  - hour_start: INT                -- 7
  - hour_end: INT                  -- 8
  - scheduled_count: INT
  - completed_count: INT
  - missed_count: INT
  - empty_count: INT               -- Horários sem ninguém agendado
  - fill_percentage: FLOAT         -- % de cobertura
  - period_name: TEXT              -- "Manhã", "Tarde", "Noite", "Madrugada"
```

**Propósito**: Tab "Por Horário"  
**Esforço**: 1.5 dias

---

##### RPC 7: `get_failure_analysis()`
```sql
FUNCTION: get_failure_analysis(
  p_community_id UUID,
  p_from DATE,
  p_to DATE
)
RETURNS TABLE:
  - user_id: UUID
  - user_name: TEXT
  - failed_count: INT              -- Quantas vezes faltou
  - assigned_count: INT
  - failure_rate: FLOAT            -- % de faltas
  - rank: INT                      -- 1=maior faltoso, N=menor
  - uncovered_targets_json: JSONB  -- Alvos que ele deixou descobertos
  - uncovered_regions_json: JSONB  -- Regiões que ele deixou descobertas
  - uncovered_time_slots_json: JSONB  -- Horários que ficaram vazios
  - last_failure_at: TIMESTAMPTZ
```

**Propósito**: Tab "Análise de Falhas"  
**Esforço**: 1.5 dias

---

##### RPC 8: `get_prayer_report_cross_data()` ⭐ GENÉRICA
```sql
FUNCTION: get_prayer_report_cross_data(
  p_community_id UUID,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  -- Filtros
  p_user_ids UUID[] DEFAULT NULL,
  p_target_ids UUID[] DEFAULT NULL,
  p_region_ids UUID[] DEFAULT NULL,
  p_statuses TEXT[] DEFAULT NULL,  -- 'completed', 'missed', 'scheduled', 'cancelled'
  p_weekdays INT[] DEFAULT NULL,   -- 0=Dom, 6=Sab
  p_hour_start INT DEFAULT 0,
  p_hour_end INT DEFAULT 23,
  -- Paginação
  p_limit INT DEFAULT 200,
  p_offset INT DEFAULT 0
)
RETURNS TABLE:
  -- Retorna dados cruzados baseado na combinação de filtros
  - run_id: UUID
  - user_id: UUID
  - user_name: TEXT
  - target_id: UUID
  - target_name: TEXT
  - region_id: UUID
  - region_name: TEXT
  - scheduled_at: TIMESTAMPTZ
  - actual_at: TIMESTAMPTZ
  - status: TEXT
  - duration_seconds: INT
  - notes: TEXT
```

**Propósito**: Relatório genérico com filtros cruzados (exemplo: mai, comunidade X, usuários, alvo Y, 19-22h)  
**Esforço**: 2 dias

---

**Total Fase 2**: 4-5 dias

---

### FASE 3: Modelos e Repository Flutter (⏱️ 2-3 dias)

#### 3.1 Novos Models (adicionar em main.dart)

```dart
// ===== MODELS DE RELATÓRIO =====

class PrayerScaleSummaryModel {
  final int totalScales;
  final int totalRuns;
  final int totalCompleted;
  final int totalMissed;
  final int totalCancelled;
  final double completionRate;
  final int uniqueUsers;
  final Duration totalPrayerTime;
  final int avgSessionDurationMinutes;
  
  PrayerScaleSummaryModel({
    required this.totalScales,
    required this.totalRuns,
    required this.totalCompleted,
    required this.totalMissed,
    required this.totalCancelled,
    required this.completionRate,
    required this.uniqueUsers,
    required this.totalPrayerTime,
    required this.avgSessionDurationMinutes,
  });
  
  factory PrayerScaleSummaryModel.fromSupabase(Map<String, dynamic> data) => PrayerScaleSummaryModel(
    totalScales: data['total_scales'] as int? ?? 0,
    totalRuns: data['total_runs'] as int? ?? 0,
    totalCompleted: data['total_completed'] as int? ?? 0,
    totalMissed: data['total_missed'] as int? ?? 0,
    totalCancelled: data['total_cancelled'] as int? ?? 0,
    completionRate: (data['completion_rate'] as num?)?.toDouble() ?? 0.0,
    uniqueUsers: data['unique_users'] as int? ?? 0,
    totalPrayerTime: Duration(seconds: (data['total_seconds'] as int?) ?? 0),
    avgSessionDurationMinutes: data['avg_session_duration'] as int? ?? 0,
  );
}

class UserPrayerStatsModel {
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final int turnsAssigned;
  final int turnsCompleted;
  final int turnsMissed;
  final int turnsCancelled;
  final double completionPercentage;
  final int avgDurationMinutes;
  final DateTime? lastCompletedAt;
  final DateTime? lastAssignedAt;
  final int pendingRunsCount;
  final List<String> commonHours;
  final int streakDays;
  
  // Getters úteis
  bool get isHighPerformer => completionPercentage >= 90;
  bool get needsAttention => completionPercentage < 50;
  
  UserPrayerStatsModel({
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.turnsAssigned,
    required this.turnsCompleted,
    required this.turnsMissed,
    required this.turnsCancelled,
    required this.completionPercentage,
    required this.avgDurationMinutes,
    this.lastCompletedAt,
    this.lastAssignedAt,
    required this.pendingRunsCount,
    required this.commonHours,
    required this.streakDays,
  });
  
  factory UserPrayerStatsModel.fromSupabase(Map<String, dynamic> data) => UserPrayerStatsModel(
    userId: data['user_id'] as String,
    userName: data['user_name'] as String? ?? 'Usuário',
    userAvatarUrl: data['user_avatar_url'] as String?,
    turnsAssigned: data['turns_assigned'] as int? ?? 0,
    turnsCompleted: data['turns_completed'] as int? ?? 0,
    turnsMissed: data['turns_missed'] as int? ?? 0,
    turnsCancelled: data['turns_cancelled'] as int? ?? 0,
    completionPercentage: (data['completion_percentage'] as num?)?.toDouble() ?? 0.0,
    avgDurationMinutes: data['avg_duration_minutes'] as int? ?? 0,
    lastCompletedAt: data['last_completed_at'] != null ? DateTime.parse(data['last_completed_at']) : null,
    lastAssignedAt: data['last_assigned_at'] != null ? DateTime.parse(data['last_assigned_at']) : null,
    pendingRunsCount: data['pending_runs_count'] as int? ?? 0,
    commonHours: List<String>.from(data['common_hours'] as List? ?? []),
    streakDays: data['streak_days'] as int? ?? 0,
  );
}

class PrayerByCompletionModel {
  final List<PrayerRunDetailModel> completed;
  final List<PrayerRunDetailModel> missed;
  final List<PrayerRunDetailModel> cancelled;
  final List<PrayerRunDetailModel> scheduled;
  
  int get totalCompleted => completed.length;
  int get totalMissed => missed.length;
  int get totalCount => completed.length + missed.length + cancelled.length + scheduled.length;
  
  PrayerByCompletionModel({
    required this.completed,
    required this.missed,
    required this.cancelled,
    required this.scheduled,
  });
}

class PrayerRunDetailModel {
  final String runId;
  final String status;  // 'completed', 'missed', 'scheduled', 'cancelled'
  final DateTime scheduledAt;
  final DateTime? actualAt;
  final String? targetName;
  final String? communityName;
  final String? responsibleName;
  final int plannedDurationMinutes;
  final int? actualDurationMinutes;
  final String? notes;
  
  String get displayStatus => {
    'completed': 'Cumprida',
    'missed': 'Não cumprida',
    'scheduled': 'Agendada',
    'cancelled': 'Cancelada',
  }[status] ?? status;
  
  PrayerRunDetailModel({
    required this.runId,
    required this.status,
    required this.scheduledAt,
    this.actualAt,
    this.targetName,
    this.communityName,
    this.responsibleName,
    required this.plannedDurationMinutes,
    this.actualDurationMinutes,
    this.notes,
  });
  
  factory PrayerRunDetailModel.fromSupabase(Map<String, dynamic> data) => PrayerRunDetailModel(
    runId: data['run_id'] as String,
    status: data['status'] as String? ?? 'scheduled',
    scheduledAt: DateTime.parse(data['scheduled_at']),
    actualAt: data['actual_at'] != null ? DateTime.parse(data['actual_at']) : null,
    targetName: data['target_name'] as String?,
    communityName: data['community_name'] as String?,
    responsibleName: data['user_name'] as String?,
    plannedDurationMinutes: data['planned_duration'] as int? ?? 0,
    actualDurationMinutes: data['actual_duration'] as int?,
    notes: data['notes'] as String?,
  );
}

class RegionCoverageModel {
  final String regionId;
  final String regionName;
  final int totalTurns;
  final int completedTurns;
  final int missedTurns;
  final double coveragePercentage;
  final int uniqueUsers;
  final int avgDurationMinutes;
  final int rank;
  
  RegionCoverageModel({
    required this.regionId,
    required this.regionName,
    required this.totalTurns,
    required this.completedTurns,
    required this.missedTurns,
    required this.coveragePercentage,
    required this.uniqueUsers,
    required this.avgDurationMinutes,
    required this.rank,
  });
  
  factory RegionCoverageModel.fromSupabase(Map<String, dynamic> data) => RegionCoverageModel(
    regionId: data['region_id'] as String? ?? '',
    regionName: data['region_name'] as String? ?? 'Desconhecida',
    totalTurns: data['total_runs'] as int? ?? 0,
    completedTurns: data['completed_runs'] as int? ?? 0,
    missedTurns: data['missed_runs'] as int? ?? 0,
    coveragePercentage: (data['coverage_percentage'] as num?)?.toDouble() ?? 0.0,
    uniqueUsers: data['unique_users'] as int? ?? 0,
    avgDurationMinutes: data['avg_duration'] as int? ?? 0,
    rank: data['rank'] as int? ?? 0,
  );
}

class TargetCoverageModel {
  final String targetId;
  final String targetName;
  final String? targetEmoji;
  final int totalTurns;
  final int completedTurns;
  final int missedTurns;
  final double coveragePercentage;
  final int uniqueUsers;
  final int rank;
  final List<UserResponsibilityModel> responsibleUsers;
  
  TargetCoverageModel({
    required this.targetId,
    required this.targetName,
    this.targetEmoji,
    required this.totalTurns,
    required this.completedTurns,
    required this.missedTurns,
    required this.coveragePercentage,
    required this.uniqueUsers,
    required this.rank,
    required this.responsibleUsers,
  });
  
  factory TargetCoverageModel.fromSupabase(Map<String, dynamic> data) => TargetCoverageModel(
    targetId: data['target_id'] as String? ?? '',
    targetName: data['target_name'] as String? ?? 'Alvo',
    targetEmoji: data['target_emoji'] as String?,
    totalTurns: data['total_runs'] as int? ?? 0,
    completedTurns: data['completed_runs'] as int? ?? 0,
    missedTurns: data['missed_runs'] as int? ?? 0,
    coveragePercentage: (data['coverage_percentage'] as num?)?.toDouble() ?? 0.0,
    uniqueUsers: data['unique_users'] as int? ?? 0,
    rank: data['rank'] as int? ?? 0,
    responsibleUsers: _parseResponsibleUsers(data['responsible_users_json']),
  );
  
  static List<UserResponsibilityModel> _parseResponsibleUsers(dynamic json) {
    if (json == null) return [];
    if (json is String) json = jsonDecode(json);
    if (json is! List) return [];
    return json.map((e) => UserResponsibilityModel.fromMap(e)).toList();
  }
}

class UserResponsibilityModel {
  final String userId;
  final String userName;
  final int count;
  
  UserResponsibilityModel({
    required this.userId,
    required this.userName,
    required this.count,
  });
  
  factory UserResponsibilityModel.fromMap(Map<String, dynamic> data) => UserResponsibilityModel(
    userId: data['id'] as String? ?? '',
    userName: data['name'] as String? ?? 'Usuário',
    count: data['count'] as int? ?? 0,
  );
}

class TimeSlotCoverageModel {
  final String timeSlot;       // "07:00-08:00"
  final int hourStart;
  final int hourEnd;
  final int scheduledCount;
  final int completedCount;
  final int missedCount;
  final int emptyCount;
  final double fillPercentage;
  final String periodName;     // "Manhã", "Tarde", "Noite", "Madrugada"
  
  TimeSlotCoverageModel({
    required this.timeSlot,
    required this.hourStart,
    required this.hourEnd,
    required this.scheduledCount,
    required this.completedCount,
    required this.missedCount,
    required this.emptyCount,
    required this.fillPercentage,
    required this.periodName,
  });
  
  factory TimeSlotCoverageModel.fromSupabase(Map<String, dynamic> data) => TimeSlotCoverageModel(
    timeSlot: data['time_slot'] as String? ?? '',
    hourStart: data['hour_start'] as int? ?? 0,
    hourEnd: data['hour_end'] as int? ?? 23,
    scheduledCount: data['scheduled_count'] as int? ?? 0,
    completedCount: data['completed_count'] as int? ?? 0,
    missedCount: data['missed_count'] as int? ?? 0,
    emptyCount: data['empty_count'] as int? ?? 0,
    fillPercentage: (data['fill_percentage'] as num?)?.toDouble() ?? 0.0,
    periodName: data['period_name'] as String? ?? 'Geral',
  );
}

class FailureAnalysisModel {
  final String userId;
  final String userName;
  final int failedCount;
  final int assignedCount;
  final double failureRate;
  final int rank;
  final List<String> uncoveredTargets;
  final List<String> uncoveredRegions;
  final List<String> uncoveredTimeSlots;
  final DateTime? lastFailureAt;
  
  FailureAnalysisModel({
    required this.userId,
    required this.userName,
    required this.failedCount,
    required this.assignedCount,
    required this.failureRate,
    required this.rank,
    required this.uncoveredTargets,
    required this.uncoveredRegions,
    required this.uncoveredTimeSlots,
    this.lastFailureAt,
  });
  
  factory FailureAnalysisModel.fromSupabase(Map<String, dynamic> data) => FailureAnalysisModel(
    userId: data['user_id'] as String? ?? '',
    userName: data['user_name'] as String? ?? 'Usuário',
    failedCount: data['failed_count'] as int? ?? 0,
    assignedCount: data['assigned_count'] as int? ?? 0,
    failureRate: (data['failure_rate'] as num?)?.toDouble() ?? 0.0,
    rank: data['rank'] as int? ?? 0,
    uncoveredTargets: _parseJsonArray(data['uncovered_targets_json']),
    uncoveredRegions: _parseJsonArray(data['uncovered_regions_json']),
    uncoveredTimeSlots: _parseJsonArray(data['uncovered_time_slots_json']),
    lastFailureAt: data['last_failure_at'] != null ? DateTime.parse(data['last_failure_at']) : null,
  );
  
  static List<String> _parseJsonArray(dynamic json) {
    if (json == null) return [];
    if (json is String) json = jsonDecode(json);
    if (json is! List) return [];
    return json.cast<String>();
  }
}

// ===== FILTER MODEL =====

class PrayerFilterOptions {
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<String> userIds;
  final List<String> targetIds;
  final List<String> regionIds;
  final List<String> statuses;  // 'completed', 'missed', 'scheduled', 'cancelled'
  final List<int> weekdays;     // 0=Dom, 6=Sab
  final int? hourStart;
  final int? hourEnd;
  
  PrayerFilterOptions({
    this.fromDate,
    this.toDate,
    this.userIds = const [],
    this.targetIds = const [],
    this.regionIds = const [],
    this.statuses = const [],
    this.weekdays = const [],
    this.hourStart,
    this.hourEnd,
  });
  
  // Helper para criar filtros comuns
  factory PrayerFilterOptions.today() => PrayerFilterOptions(
    fromDate: DateTime.now(),
    toDate: DateTime.now().add(Duration(days: 1)),
  );
  
  factory PrayerFilterOptions.thisWeek() {
    final now = DateTime.now();
    final daysToMonday = (now.weekday - 1) % 7;
    final monday = now.subtract(Duration(days: daysToMonday));
    return PrayerFilterOptions(
      fromDate: monday,
      toDate: monday.add(Duration(days: 7)),
    );
  }
  
  factory PrayerFilterOptions.thisMonth() {
    final now = DateTime.now();
    return PrayerFilterOptions(
      fromDate: DateTime(now.year, now.month, 1),
      toDate: DateTime(now.year, now.month + 1, 0),
    );
  }
  
  bool hasAnyFilter() => 
    userIds.isNotEmpty ||
    targetIds.isNotEmpty ||
    regionIds.isNotEmpty ||
    statuses.isNotEmpty ||
    weekdays.isNotEmpty ||
    hourStart != null ||
    hourEnd != null;
}
```

**Esforço**: 1-2 dias

---

#### 3.2 Extensão do DemoRepository

```dart
class DemoRepository {
  // ... métodos existentes ...
  
  // ===== NOVOS MÉTODOS DE RELATÓRIO =====
  
  /// Obter resumo geral de escalas
  Future<PrayerScaleSummaryModel> getPrayerScaleSummary(
    String communityId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final response = await supabase.rpc(
        'get_prayer_scale_summary',
        params: {
          'p_community_id': communityId,
          'p_from': from.toUtc().toString().split(' ').first,
          'p_to': to.toUtc().toString().split(' ').first,
        },
      );
      
      if (response.isEmpty) {
        throw Exception('No summary data');
      }
      
      return PrayerScaleSummaryModel.fromSupabase(response[0]);
    } catch (e) {
      _logger('Error fetching prayer scale summary', e);
      rethrow;
    }
  }
  
  /// Obter estatísticas detalhadas por usuário
  Future<List<UserPrayerStatsModel>> getUserPrayerStats(
    String communityId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final response = await supabase.rpc(
        'get_prayer_by_user_detailed',
        params: {
          'p_community_id': communityId,
          'p_from': from.toUtc().toString().split(' ').first,
          'p_to': to.toUtc().toString().split(' ').first,
        },
      );
      
      return (response as List)
          .map((e) => UserPrayerStatsModel.fromSupabase(e))
          .toList();
    } catch (e) {
      _logger('Error fetching user prayer stats', e);
      rethrow;
    }
  }
  
  /// Obter orações agrupadas por status de conclusão
  Future<PrayerByCompletionModel> getPrayersByCompletionStatus(
    String communityId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final response = await supabase.rpc(
        'get_prayers_by_completion_status',
        params: {
          'p_community_id': communityId,
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
        },
      );
      
      final completed = <PrayerRunDetailModel>[];
      final missed = <PrayerRunDetailModel>[];
      final cancelled = <PrayerRunDetailModel>[];
      final scheduled = <PrayerRunDetailModel>[];
      
      for (final item in response) {
        final model = PrayerRunDetailModel.fromSupabase(item);
        switch (model.status) {
          case 'completed':
            completed.add(model);
          case 'missed':
            missed.add(model);
          case 'cancelled':
            cancelled.add(model);
          case 'scheduled':
            scheduled.add(model);
        }
      }
      
      return PrayerByCompletionModel(
        completed: completed,
        missed: missed,
        cancelled: cancelled,
        scheduled: scheduled,
      );
    } catch (e) {
      _logger('Error fetching prayers by completion status', e);
      rethrow;
    }
  }
  
  /// Obter cobertura por região
  Future<List<RegionCoverageModel>> getRegionCoverage(
    String communityId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final response = await supabase.rpc(
        'get_coverage_by_region',
        params: {
          'p_community_id': communityId,
          'p_from': from.toUtc().toString().split(' ').first,
          'p_to': to.toUtc().toString().split(' ').first,
        },
      );
      
      return (response as List)
          .map((e) => RegionCoverageModel.fromSupabase(e))
          .toList();
    } catch (e) {
      _logger('Error fetching region coverage', e);
      rethrow;
    }
  }
  
  /// Obter cobertura por alvo de oração
  Future<List<TargetCoverageModel>> getTargetCoverage(
    String communityId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final response = await supabase.rpc(
        'get_coverage_by_target',
        params: {
          'p_community_id': communityId,
          'p_from': from.toUtc().toString().split(' ').first,
          'p_to': to.toUtc().toString().split(' ').first,
        },
      );
      
      return (response as List)
          .map((e) => TargetCoverageModel.fromSupabase(e))
          .toList();
    } catch (e) {
      _logger('Error fetching target coverage', e);
      rethrow;
    }
  }
  
  /// Obter cobertura por slot de horário
  Future<List<TimeSlotCoverageModel>> getTimeSlotCoverage(
    String communityId,
    DateTime from,
    DateTime to,
    int slotMinutes = 60,
  ) async {
    try {
      final response = await supabase.rpc(
        'get_time_slot_coverage',
        params: {
          'p_community_id': communityId,
          'p_from': from.toUtc().toString().split(' ').first,
          'p_to': to.toUtc().toString().split(' ').first,
          'p_slot_minutes': slotMinutes,
        },
      );
      
      return (response as List)
          .map((e) => TimeSlotCoverageModel.fromSupabase(e))
          .toList();
    } catch (e) {
      _logger('Error fetching time slot coverage', e);
      rethrow;
    }
  }
  
  /// Obter análise de falhas
  Future<List<FailureAnalysisModel>> getFailureAnalysis(
    String communityId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final response = await supabase.rpc(
        'get_failure_analysis',
        params: {
          'p_community_id': communityId,
          'p_from': from.toUtc().toString().split(' ').first,
          'p_to': to.toUtc().toString().split(' ').first,
        },
      );
      
      return (response as List)
          .map((e) => FailureAnalysisModel.fromSupabase(e))
          .toList();
    } catch (e) {
      _logger('Error fetching failure analysis', e);
      rethrow;
    }
  }
  
  /// Relatório genérico com filtros cruzados (PODEROSO!)
  Future<List<Map<String, dynamic>>> getPrayerReportCrossData(
    String communityId,
    PrayerFilterOptions filters,
    {int limit = 200, int offset = 0}
  ) async {
    try {
      final response = await supabase.rpc(
        'get_prayer_report_cross_data',
        params: {
          'p_community_id': communityId,
          'p_from': (filters.fromDate ?? DateTime.now().subtract(Duration(days: 30)))
              .toUtc()
              .toIso8601String(),
          'p_to': (filters.toDate ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
          'p_user_ids': filters.userIds.isEmpty ? null : filters.userIds,
          'p_target_ids': filters.targetIds.isEmpty ? null : filters.targetIds,
          'p_region_ids': filters.regionIds.isEmpty ? null : filters.regionIds,
          'p_statuses': filters.statuses.isEmpty ? null : filters.statuses,
          'p_weekdays': filters.weekdays.isEmpty ? null : filters.weekdays,
          'p_hour_start': filters.hourStart ?? 0,
          'p_hour_end': filters.hourEnd ?? 23,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _logger('Error fetching cross data', e);
      rethrow;
    }
  }
}
```

**Esforço**: 1 dia

---

**Total Fase 3**: 2-3 dias

---

### FASE 4: UI/Widgets - Relatório Incremental (⏱️ 4 semanas)

#### Estrutura da Tela Proposta

```
PrayerReportScreen
├─ SafeArea
│  └─ Scaffold
│     ├─ AppBar: "Relatório de Escalas"
│     │
│     ├─ Body: SingleChildScrollView
│     │  ├─ Section 1: CARDS RESUMIDOS
│     │  │  └─ Row<4 cards>: Total Escalas, Turnos, Cumpridas, %
│     │  │
│     │  ├─ Section 2: FILTROS COMBINÁVEIS
│     │  │  ├─ Row: DateRange selector + "Limpar Filtros" button
│     │  │  ├─ Wrap: Comunidade, Região, Usuário dropdowns
│     │  │  ├─ Wrap: Alvo, Status, Horário, Dia da semana selectors
│     │  │  └─ Button: "Aplicar Filtros" (loading indicator)
│     │  │
│     │  ├─ Section 3: GRÁFICOS
│     │  │  ├─ BarChart: Distribuição de cumprimento
│     │  │  ├─ PieChart: % Cumprimento vs Não Cumprido
│     │  │  └─ LineChart: Trend ao longo do período
│     │  │
│     │  └─ Section 4: TABS DE RELATÓRIOS
│     │     ├─ TabBar: 7 abas
│     │     └─ TabBarView:
│     │        ├─ Tab 1: Dashboard (cards + stats)
│     │        ├─ Tab 2: Por Usuário (lista + detalhe)
│     │        ├─ Tab 3: Por Orações (agrupado)
│     │        ├─ Tab 4: Por Região (tabela)
│     │        ├─ Tab 5: Por Alvo (tabela)
│     │        ├─ Tab 6: Por Horário (tabela)
│     │        └─ Tab 7: Análise de Falhas (ranking)
│     │
│     └─ BottomBar:
│        ├─ Button: "Exportar PDF"
│        ├─ Button: "Exportar CSV"
│        └─ Text: "Atualizado às HH:MM"
```

---

#### Sprint 1: Dashboard Básico (Semana 1)

**Objetivos**:
1. Tela vazia com estrutura
2. Cards resumidos com dados mockados
3. Filtros de UI (sem lógica)
4. Conectar 1ª RPC (summary)

**Componentes**:
- `PrayerReportScreen` (main)
- `PrayerSummaryCard` (card individual)
- `PrayerFilterBar` (row de filtros)

**Esforço**: 3-4 dias

---

#### Sprint 2: Por Usuário + Por Orações (Semana 2)

**Objetivos**:
1. Tab "Por Usuário" funcional
2. Tab "Por Orações" com agrupamento
3. Conectar 2ª + 3ª RPCs
4. Detalhe ao clicar em usuário

**Componentes**:
- `UserPrayerList`
- `UserPrayerCard` (detalhe expandível)
- `PrayerCompletionGrouped`
- `PrayerRunTile`

**Esforço**: 3-4 dias

---

#### Sprint 3: Região + Alvo + Horário (Semana 3)

**Objetivos**:
1. Tab "Por Região" com tabela
2. Tab "Por Alvo" com lista de responsáveis
3. Tab "Por Horário" com slots vazios
4. Charts (Bar, Pie)
5. Conectar 4ª, 5ª, 6ª RPCs

**Componentes**:
- `RegionCoverageTable`
- `TargetCoverageCard`
- `TimeSlotGrid`
- `CoverageChart`

**Esforço**: 4-5 dias

---

#### Sprint 4: Falhas + Filtros + Exportar (Semana 4)

**Objetivos**:
1. Tab "Análise de Falhas" com ranking
2. Implementar lógica de filtros cruzados
3. Botão "Exportar PDF/CSV"
4. Testes e refinamento

**Componentes**:
- `FailureAnalysisRanking`
- `FilterLogicEngine`
- `ReportExporter`

**Esforço**: 4-5 dias

---

**Total Fase 4**: 4 semanas

---

### FASE 5: Filtros Cruzados (⏱️ 2-3 dias, em paralelo com Fase 4)

#### 5.1 Exemplo: Filtro Complexo

```dart
// Requisição:
// "Maio de 2026, comunidade 'Atalaia Global', 
//  usuários não cumpriram, alvo 'Pela Nação', 19-22h"

final filters = PrayerFilterOptions(
  fromDate: DateTime(2026, 5, 1),
  toDate: DateTime(2026, 5, 31),
  communityIds: ['atalaia-global-id'],  // ← comunidade
  statuses: ['missed'],                  // ← não cumpridos
  targetIds: ['nacao-target-id'],        // ← alvo
  hourStart: 19,                         // ← horário
  hourEnd: 22,
);

// A RPC genérica retornará apenas os runs que satisfazem TODOS os filtros
final results = await repo.getPrayerReportCrossData(
  'community-id',
  filters,
);

// results conterá:
// [
//   { run_id, user_id, user_name, target_name, region_name, 
//     scheduled_at, actual_at, status, duration, notes },
//   ...
// ]
```

**Implementação**: 2-3 dias na RPC SQL + 1 dia na lógica Flutter

---

### FASE 6: Reutilização e Padrões (⏱️ 1-2 dias, após Fase 4)

#### 6.1 Helper Functions (adicionar em main.dart)

```dart
// Formatação de duração
String formatDurationForReport(Duration duration) {
  if (duration.inSeconds < 60) return '${duration.inSeconds}s';
  if (duration.inMinutes < 60) return '${duration.inMinutes}m';
  final hours = duration.inHours;
  final mins = duration.inMinutes % 60;
  return '${hours}h ${mins}m';
}

// Formatação de percentual
String formatPercentage(double percentage, {int decimals = 1}) {
  return '${percentage.toStringAsFixed(decimals)}%';
}

// Gerar relatório em texto
String generateTextReport(PrayerScaleSummaryModel summary) {
  return '''
RELATÓRIO DE ESCALAS DE ORAÇÃO
================================
Período: ...
Total de Escalas: ${summary.totalScales}
Total de Turnos: ${summary.totalRuns}
Cumpridos: ${summary.totalCompleted}
Não Cumpridos: ${summary.totalMissed}
Taxa de Cumprimento: ${formatPercentage(summary.completionRate)}
Usuários Participantes: ${summary.uniqueUsers}
Tempo Total de Oração: ${formatDurationForReport(summary.totalPrayerTime)}
''';
}

// Exportar para CSV
String convertListToCsv(List<Map<String, dynamic>> data) {
  if (data.isEmpty) return '';
  
  // Headers
  final headers = data.first.keys.toList();
  final csv = StringBuffer();
  csv.writeln(headers.join(','));
  
  // Rows
  for (final row in data) {
    final values = headers.map((h) => _escapeCsv(row[h]?.toString() ?? ''));
    csv.writeln(values.join(','));
  }
  
  return csv.toString();
}

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

// Agrupar dados por período
Map<String, List<T>> groupByPeriod<T>(
  List<T> items,
  DateTime Function(T) getDate,
) {
  final grouped = <String, List<T>>{};
  for (final item in items) {
    final date = getDate(item);
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    grouped.putIfAbsent(key, () => []).add(item);
  }
  return grouped;
}
```

**Esforço**: 1-2 dias

---

## 📊 TIMELINE CONSOLIDADA

| Fase | Descrição | Duração | Início | Fim |
|------|-----------|---------|--------|-----|
| **1** | Diagnóstico | ✅ CONCLUÍDA | - | - |
| **2** | Backend BD + 8 RPCs | 4-5 dias | **PRÓXIMO** | **+1 semana** |
| **3** | Models + Repository | 2-3 dias | +3 dias | +1.5 semanas |
| **4** | UI (4 sprints) | 4 semanas | +5 dias | +6 semanas |
| **5** | Filtros Cruzados | 2-3 dias | +1 semana (paralelo) | +2 semanas |
| **6** | Helpers + Reutilização | 1-2 dias | +5 semanas | +5.5 semanas |
| | **TOTAL ESTIMADO** | **5-6 semanas** | | |

---

## 🎯 PRÓXIMOS PASSOS IMEDIATOS

### **HOJE - Fase 2.1**
- [ ] Criar migration: `20260428_prayer_targets_table.sql`
- [ ] Adicionar coluna `prayer_target_id` em `community_prayer_schedules`
- [ ] Deploy migration ao Supabase

### **AMANHÃ - Fase 2.2**
- [ ] Implementar 8 RPCs SQL (começar com `get_prayer_scale_summary`)
- [ ] Testar cada RPC individualmente

### **ESTA SEMANA - Fase 3**
- [ ] Criar Models Dart (copiar código acima para main.dart)
- [ ] Adicionar métodos ao `DemoRepository`
- [ ] Testar conexão e desserialização JSON

### **PRÓXIMA SEMANA - Fase 4, Sprint 1**
- [ ] Criar `PrayerReportScreen` vazia
- [ ] Implementar cards resumidos
- [ ] Conectar 1ª RPC

---

## 💡 BOAS PRÁTICAS DURANTE IMPLEMENTAÇÃO

1. **Testar cada RPC isoladamente** antes de integrar com Flutter
2. **Mockar dados** para desenvolver UI sem depender de backend
3. **Usar paginação** em listas grandes (limit 50-100 por requisição)
4. **Cachear resultados** por 5-10 minutos para evitar sobrecarga
5. **Adicionar loading states** em todas as requisições
6. **Tratar erros gracefully** (offline, timeout, sem dados)
7. **Usar localizações** para todos os textos (PT/EN/ES)
8. **Testar com dados reais** antes de deploy

---

## 🏗️ ESTRUTURA DE PASTAS (proposta)

```
Supabase/
└─ migrations/
   ├─ 20260428_prayer_targets_table.sql     (Nova)
   └─ 20260428_prayer_report_functions.sql  (Nova, 8 RPCs)

App/lib/
└─ main.dart
   ├─ (Novos Models) - 200+ linhas
   ├─ (Novos métodos DemoRepository) - 300+ linhas
   ├─ (Nova classe PrayerReportScreen) - 1000+ linhas
   └─ (Novos Widgets auxiliares) - 500+ linhas
```

---

## 🎁 EXTRAS & MELHORIAS FUTURAS

### Pós-MVP (Fase 7+)

- **Alertas Automáticos**: Notificar admin se cumprimento < 70%
- **Comparação de Períodos**: Mês passado vs. mês atual
- **Previsões IA**: Ranking de probabilidade de faltas
- **Agenda Interativa**: Reatribuir turnos com drag-drop
- **Integração Whatsapp**: Enviar relatório em PDF via bot
- **Gamificação**: Badges e troféus para high performers
- **Templates Personalizados**: Salvar filtros como templates

---

## 📞 PERGUNTAS/DECISÕES NECESSÁRIAS

Antes de iniciar Fase 2, confirme:

1. ✅ **Permissões**: Quem pode ver cada relatório? (admin comunitário? global? membro?)
2. ✅ **Histórico**: Manter histórico de faltas (audit trail)?
3. ✅ **Notificações**: Avisar usuários sobre seus próprios relatórios?
4. ✅ **Exportação**: Qual formato prioritário? (PDF, CSV, ambos?)
5. ✅ **Timezone**: Como lidar com fusos horários diferentes?
6. ✅ **Realtime**: Atualizar gráficos em tempo real ou manual?

---

**Documento atualizado**: 28/04/2026  
**Roadmap Status**: Pronto para execução  
**Próximo Check-in**: Após conclusão Fase 2
