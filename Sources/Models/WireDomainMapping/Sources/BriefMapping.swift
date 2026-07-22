import DomainModels
import WireModels

// The brief entry points. They are non-throwing: the closed enums are SHARED wire↔domain (Phase
// 11.3) and decode STRICTLY at the `WireModels` boundary, so an out-of-set closed enum is impossible
// by the time the DTO reaches a mapper — there is no totality channel left. Only the three
// free-string fields (`flag`/`safetyReason`/`penaltyFactor`) can carry an unrecognised value, and
// those fall back to `.unknown(raw)` rather than failing.

/// Map a wire `DailyBrief` to the domain, flattening the `{ data, narrative }` envelope.
public func domainDailyBrief(_ dto: WireModels.DailyBrief) -> DomainModels.DailyBrief {
  let data = dto.data
  return DomainModels.DailyBrief(
    date: data.date.value,
    readiness: DomainModels.Readiness(
      score: data.readiness.score,
      band: data.readiness.band,
      penalties: data.readiness.penalties.map {
        DomainModels.ReadinessPenalty(factor: PenaltyFactor(wireString: $0.factor), points: $0.points)
      }
    ),
    safetyGate: safetyGate(data.safetyGate),
    session: makeSession(data.session),
    alternatives: data.alternatives.map(makeSession),
    skipOk: data.skipOk,
    macroFocus: macroFocus(data.macroFocus),
    intakeYesterday: data.intakeYesterday.map(domainIntake),
    generatedAt: data.generatedAt,
    cached: data.cached,
    constitutionVersion: data.constitutionVersion,
    narrative: narrative(dto.narrative)
  )
}

/// Map a wire `WeeklyPlan` to the domain, flattening the `{ data, narrative }` envelope.
public func domainWeeklyPlan(_ dto: WireModels.WeeklyPlan) -> DomainModels.WeeklyPlan {
  let data = dto.data
  return DomainModels.WeeklyPlan(
    isoWeek: data.isoWeek,
    weekStart: data.weekStart.value,
    budgets: budgets(data.budgets),
    core: data.core.map(plannedSession),
    extras: data.extras.map(plannedSession),
    targets: targets(data.targets),
    nutrition: nutrition(data.nutrition),
    constantsRecomputed: data.constantsRecomputed,
    generatedAt: data.generatedAt,
    cached: data.cached,
    narrative: narrative(dto.narrative)
  )
}

// MARK: - Sessions

private func makeSession(_ dto: WireModels.SessionBlock) -> DomainModels.SessionBlock {
  DomainModels.SessionBlock(
    card: dto.card,
    intensity: dto.intensity,
    zoneTarget: dto.zoneTarget,
    durationMinLow: dto.durationMinLow,
    durationMinHigh: dto.durationMinHigh,
    hrCapBpm: dto.hrCapBpm,
    cadenceSpm: dto.cadenceSpm,
    flags: dto.flags.map(Flag.init(wireString:))
  )
}

private func plannedSession(_ dto: WireModels.PlannedSession) -> DomainModels.PlannedSession {
  DomainModels.PlannedSession(
    card: dto.card,
    tier: dto.tier,
    intensity: dto.intensity,
    isHardDay: dto.isHardDay,
    suggestedDay: dto.suggestedDay,
    zoneTarget: dto.zoneTarget,
    durationMinLow: dto.durationMinLow,
    durationMinHigh: dto.durationMinHigh,
    flags: dto.flags.map(Flag.init(wireString:))
  )
}

// MARK: - Other sub-shapes

private func safetyGate(_ dto: WireModels.SafetyGate) -> DomainModels.SafetyGate {
  DomainModels.SafetyGate(
    triggered: dto.triggered,
    reasons: dto.reasons.map(SafetyReason.init(wireString:)),
    overrideTo: dto.overrideTo
  )
}

private func macroFocus(_ dto: WireModels.MacroFocus) -> DomainModels.MacroFocus {
  DomainModels.MacroFocus(
    dayType: dto.dayType,
    caloriesKcal: dto.caloriesKcal,
    proteinG: dto.proteinG,
    carbsG: dto.carbsG,
    fatGLow: dto.fatGLow,
    fatGHigh: dto.fatGHigh,
    hydrationLLow: dto.hydrationLLow,
    hydrationLHigh: dto.hydrationLHigh
  )
}

private func narrative(_ dtos: [WireModels.NarrativeSection]) -> [DomainModels.NarrativeSection] {
  dtos.map { DomainModels.NarrativeSection(type: $0.type, heading: $0.heading, body: $0.body) }
}

private func budgets(_ dto: WireModels.WeeklyBudgets) -> DomainModels.WeeklyBudgets {
  DomainModels.WeeklyBudgets(
    hardDays: dto.hardDays,
    strengthSessions: dto.strengthSessions,
    longRunKm: dto.longRunKm,
    deload: dto.deload
  )
}

private func targets(_ dto: WireModels.WeeklyTargets) -> DomainModels.WeeklyTargets {
  DomainModels.WeeklyTargets(
    totalRunKm: dto.totalRunKm,
    easyRunRatio: dto.easyRunRatio,
    strengthSessions: dto.strengthSessions,
    hardDays: dto.hardDays,
    cadenceSpm: dto.cadenceSpm
  )
}

private func nutrition(_ dto: WireModels.WeeklyNutrition) -> DomainModels.WeeklyNutrition {
  DomainModels.WeeklyNutrition(
    proteinG: dto.proteinG,
    fatGLow: dto.fatGLow,
    fatGHigh: dto.fatGHigh,
    hydrationLLow: dto.hydrationLLow,
    hydrationLHigh: dto.hydrationLHigh,
    avgCaloriesKcal: dto.avgCaloriesKcal,
    dayTypePattern: dto.dayTypePattern.map(dayTypePatternEntry),
    restDay: dto.restDay.map(restDayNutrition),
    lastWeek: dto.lastWeek.map(lastWeekNutrition)
  )
}

private func dayTypePatternEntry(
  _ dto: WireModels.DayTypePatternEntry
) -> DomainModels.DayTypePatternEntry {
  DomainModels.DayTypePatternEntry(
    suggestedDay: dto.suggestedDay,
    dayType: dto.dayType,
    caloriesKcal: dto.caloriesKcal,
    carbsG: dto.carbsG
  )
}

private func restDayNutrition(_ dto: WireModels.RestDayNutrition) -> DomainModels.RestDayNutrition {
  DomainModels.RestDayNutrition(caloriesKcal: dto.caloriesKcal, carbsG: dto.carbsG)
}

private func lastWeekNutrition(
  _ dto: WireModels.LastWeekNutrition
) -> DomainModels.LastWeekNutrition {
  DomainModels.LastWeekNutrition(
    avgCaloriesKcal: dto.avgCaloriesKcal,
    avgProteinG: dto.avgProteinG,
    proteinHitDays: dto.proteinHitDays,
    daysOverTarget: dto.daysOverTarget,
    daysUnderTarget: dto.daysUnderTarget
  )
}
