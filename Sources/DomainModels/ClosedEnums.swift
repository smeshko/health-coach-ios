// The domain's closed enums — its own twins of the wire's closed enums (it does NOT re-use the
// `WireModels` types, so the two layers can diverge; ARCHITECTURE §4.1). These stay strictly closed
// (no `.unknown` case): an out-of-set wire value is handled positionally by `WireDomainMapping`
// (drop / nil / throw — DECISIONS Decision 2), never by a domain `.unknown`. The enums carry no
// wire rawValue strings and no UX labels (those live in the mapping target and `DesignSystem`).

/// The workout/session card catalogue — domain twin of wire `WorkoutCard` (PRD §12).
public enum Card: Sendable, Hashable, CaseIterable {
  case easyRun
  case longRun
  case progressionRun
  case activeRecovery
  case threshold
  case vo2
  case strides
  case hiit
  case jumpRope
  case steadyCardio
  case strengthPush
  case strengthPull
  case strengthLower
  case strengthFull
  case boxing
  case boxingTechnique
  case footPrehab
  case glutePrehab
  case mobility
  case rest
}

/// Heart-rate zones.
public enum Zone: Sendable, Hashable, CaseIterable {
  // swiftlint:disable:next identifier_name
  case z1, z2, z3, z4, z5
}

/// Readiness band.
public enum ReadinessBand: Sendable, Hashable, CaseIterable {
  case green, amber, red
}

/// Day type.
public enum DayType: Sendable, Hashable, CaseIterable {
  case hard, moderate, rest
}

/// Session intensity.
public enum Intensity: Sendable, Hashable, CaseIterable {
  case easy, quality, recovery
}

/// Narrative section type.
public enum NarrativeType: Sendable, Hashable, CaseIterable {
  case summary, session, nutrition, caution, plan
}

/// Session tier.
public enum Tier: Sendable, Hashable, CaseIterable {
  case core, extra
}

/// Day of the week.
public enum Weekday: Sendable, Hashable, CaseIterable {
  case mon, tue, wed, thu, fri, sat, sun
}
