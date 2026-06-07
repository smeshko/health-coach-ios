import DomainModels
import WireModels

// The brief entry points. They `throw` only as the totality-preserving error channel: an out-of-set
// **required singular** closed enum (`session.card`/`.intensity`, `readiness.band`,
// `macroFocus.dayType`) has nothing to drop and no `nil` to fall back to, so it throws a
// `MappingError` the repository surfaces as a domain error (DECISIONS Decision 2). Out-of-set
// **collection elements** are dropped; out-of-set **optional singular** fields fall back to `nil`.

/// Map a wire `DailyBrief` to the domain, flattening the `{ data, narrative }` envelope.
public func domainDailyBrief(_ dto: WireModels.DailyBrief) throws -> DomainModels.DailyBrief {
  let data = dto.data

  let session = try requiredSession(data.session, field: "session")

  guard let band = EnumMapping.band(data.readiness.band) else {
    throw MappingError.unmappableRequiredEnum(
      field: "readiness.band", rawValue: data.readiness.band.rawValue
    )
  }
  guard let dayType = EnumMapping.dayType(data.macroFocus.dayType) else {
    throw MappingError.unmappableRequiredEnum(
      field: "macroFocus.dayType", rawValue: data.macroFocus.dayType.rawValue
    )
  }

  return DomainModels.DailyBrief(
    date: data.date.value,
    readiness: DomainModels.Readiness(
      score: data.readiness.score,
      band: band,
      penalties: data.readiness.penalties.map {
        DomainModels.ReadinessPenalty(factor: EnumMapping.penaltyFactor($0.factor), points: $0.points)
      }
    ),
    safetyGate: safetyGate(data.safetyGate),
    session: session,
    // Out-of-set collection elements are dropped.
    alternatives: data.alternatives.compactMap(optionalSession),
    skipOk: data.skipOk,
    macroFocus: macroFocus(data.macroFocus, dayType: dayType),
    intakeYesterday: data.intakeYesterday.map(domainIntake),
    generatedAt: data.generatedAt,
    cached: data.cached,
    constitutionVersion: data.constitutionVersion,
    narrative: narrative(dto.narrative)
  )
}

/// Map a wire `WeeklyPlan` to the domain, flattening the `{ data, narrative }` envelope.
public func domainWeeklyPlan(_ dto: WireModels.WeeklyPlan) throws -> DomainModels.WeeklyPlan {
  let data = dto.data
  return DomainModels.WeeklyPlan(
    isoWeek: data.isoWeek,
    weekStart: data.weekStart.value,
    budgets: budgets(data.budgets),
    // Out-of-set planned sessions are dropped.
    core: data.core.compactMap(optionalPlannedSession),
    extras: data.extras.compactMap(optionalPlannedSession),
    targets: targets(data.targets),
    nutrition: nutrition(data.nutrition),
    constantsRecomputed: data.constantsRecomputed,
    generatedAt: data.generatedAt,
    cached: data.cached,
    narrative: narrative(dto.narrative)
  )
}

// MARK: - Sessions

/// A required session — throws when its `card`/`intensity` is out-of-set (nothing to drop).
private func requiredSession(
  _ dto: WireModels.SessionBlock, field: String
) throws -> DomainModels.SessionBlock {
  guard let card = EnumMapping.card(dto.card) else {
    throw MappingError.unmappableRequiredEnum(field: "\(field).card", rawValue: dto.card.rawValue)
  }
  guard let intensity = EnumMapping.intensity(dto.intensity) else {
    throw MappingError.unmappableRequiredEnum(
      field: "\(field).intensity", rawValue: dto.intensity.rawValue
    )
  }
  return makeSession(dto, card: card, intensity: intensity)
}

/// A collection-element session — returns `nil` (dropped) when `card`/`intensity` is out-of-set.
private func optionalSession(_ dto: WireModels.SessionBlock) -> DomainModels.SessionBlock? {
  guard let card = EnumMapping.card(dto.card), let intensity = EnumMapping.intensity(dto.intensity)
  else { return nil }
  return makeSession(dto, card: card, intensity: intensity)
}

private func makeSession(
  _ dto: WireModels.SessionBlock,
  card: DomainModels.Card,
  intensity: DomainModels.Intensity
) -> DomainModels.SessionBlock {
  DomainModels.SessionBlock(
    card: card,
    intensity: intensity,
    zoneTarget: dto.zoneTarget.flatMap(EnumMapping.zone),
    durationMinLow: dto.durationMinLow,
    durationMinHigh: dto.durationMinHigh,
    hrCapBpm: dto.hrCapBpm,
    cadenceSpm: dto.cadenceSpm,
    flags: dto.flags.map(EnumMapping.flag)
  )
}

/// A collection-element planned session — returns `nil` (dropped) when a required closed enum
/// (`card`/`tier`/`intensity`) is out-of-set.
private func optionalPlannedSession(_ dto: WireModels.PlannedSession) -> DomainModels.PlannedSession? {
  guard let card = EnumMapping.card(dto.card),
        let tier = EnumMapping.tier(dto.tier),
        let intensity = EnumMapping.intensity(dto.intensity)
  else { return nil }
  return DomainModels.PlannedSession(
    card: card,
    tier: tier,
    intensity: intensity,
    isHardDay: dto.isHardDay,
    suggestedDay: dto.suggestedDay.flatMap(EnumMapping.weekday),
    zoneTarget: dto.zoneTarget.flatMap(EnumMapping.zone),
    durationMinLow: dto.durationMinLow,
    durationMinHigh: dto.durationMinHigh,
    flags: dto.flags.map(EnumMapping.flag)
  )
}

// MARK: - Other sub-shapes

private func safetyGate(_ dto: WireModels.SafetyGate) -> DomainModels.SafetyGate {
  DomainModels.SafetyGate(
    triggered: dto.triggered,
    reasons: dto.reasons.map(EnumMapping.safetyReason),
    overrideTo: dto.overrideTo.flatMap(EnumMapping.card)
  )
}

private func macroFocus(
  _ dto: WireModels.MacroFocus, dayType: DomainModels.DayType
) -> DomainModels.MacroFocus {
  DomainModels.MacroFocus(
    dayType: dayType,
    caloriesKcal: dto.caloriesKcal,
    proteinG: dto.proteinG,
    carbsG: dto.carbsG,
    fatGLow: dto.fatGLow,
    fatGHigh: dto.fatGHigh,
    hydrationLLow: dto.hydrationLLow,
    hydrationLHigh: dto.hydrationLHigh
  )
}

/// Narrative sections — an out-of-set `type` drops that section (collection element).
private func narrative(_ dtos: [WireModels.NarrativeSection]) -> [DomainModels.NarrativeSection] {
  dtos.compactMap { section in
    guard let type = EnumMapping.narrativeType(section.type) else { return nil }
    return DomainModels.NarrativeSection(type: type, heading: section.heading, body: section.body)
  }
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
    // An out-of-set day-type drops that pattern entry (collection element).
    dayTypePattern: dto.dayTypePattern.compactMap(dayTypePatternEntry),
    restDay: dto.restDay.map(restDayNutrition),
    lastWeek: dto.lastWeek.map(lastWeekNutrition)
  )
}

private func dayTypePatternEntry(
  _ dto: WireModels.DayTypePatternEntry
) -> DomainModels.DayTypePatternEntry? {
  guard let dayType = EnumMapping.dayType(dto.dayType) else { return nil }
  return DomainModels.DayTypePatternEntry(
    suggestedDay: dto.suggestedDay,
    dayType: dayType,
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
