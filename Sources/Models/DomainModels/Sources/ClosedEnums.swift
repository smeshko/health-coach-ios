// The domain's closed enums — its own twins of the wire's closed enums (it does NOT re-use the
// `WireModels` types, so the two layers can diverge; ARCHITECTURE §4.1). These stay strictly closed
// (no `.unknown` case): an out-of-set wire value is handled positionally by `WireDomainMapping`
// (drop / nil / throw — DECISIONS Decision 2), never by a domain `.unknown`. UX labels live in
// `DesignSystem`. The `String` raw values are the **wire strings** (copied from `WireModels`'
// closed-enum twins): the persistence body format equals the wire format, so Phase 11.3's enum
// sharing changes no persisted shape (11.2's v3 cache clear is the epic's only format break).

/// The workout/session card catalogue — domain twin of wire `WorkoutCard` (PRD §12).
public enum Card: String, Sendable, Hashable, CaseIterable, Codable {
  case easyRun = "easy_run"
  case longRun = "long_run"
  case progressionRun = "progression_run"
  case activeRecovery = "active_recovery"
  case threshold
  case vo2
  case strides
  case hiit
  case jumpRope = "jump_rope"
  case steadyCardio = "steady_cardio"
  case strengthPush = "strength_push"
  case strengthPull = "strength_pull"
  case strengthLower = "strength_lower"
  case strengthFull = "strength_full"
  case boxing
  case boxingTechnique = "boxing_technique"
  case footPrehab = "foot_prehab"
  case glutePrehab = "glute_prehab"
  case mobility
  case rest
}

/// Heart-rate zones.
public enum Zone: String, Sendable, Hashable, CaseIterable, Codable {
  // swiftlint:disable:next identifier_name
  case z1, z2, z3, z4, z5
}

/// Readiness band.
public enum ReadinessBand: String, Sendable, Hashable, CaseIterable, Codable {
  case green, amber, red
}

/// Day type.
public enum DayType: String, Sendable, Hashable, CaseIterable, Codable {
  case hard, moderate, rest
}

/// Session intensity.
public enum Intensity: String, Sendable, Hashable, CaseIterable, Codable {
  case easy, quality, recovery
}

/// Narrative section type.
public enum NarrativeType: String, Sendable, Hashable, CaseIterable, Codable {
  case summary, session, nutrition, caution, plan
}

/// Session tier.
public enum Tier: String, Sendable, Hashable, CaseIterable, Codable {
  case core, extra
}

/// Day of the week.
public enum Weekday: String, Sendable, Hashable, CaseIterable, Codable {
  case mon, tue, wed, thu, fri, sat, sun
}
