import DomainModels
import WireModels

// Note: `card` and `flag` below opt out of the cyclomatic-complexity rule — they are exhaustive 1:1
// mapping switches where the branch count *is* the table, not real decision complexity.

/// The raw-string ↔ typed-enum maps. Pure, non-throwing leaf helpers.
///
/// Closed-enum helpers return an **optional** domain value — `nil` for the wire `.unknown` sentinel
/// (Phase 2.1 decodes closed enums unknown-tolerantly). The *position-dependent* handling of that
/// `nil` (drop / `nil` / throw) lives in the shape mappers (DECISIONS Decision 2). The domain closed
/// enums stay strictly closed. Free-string helpers never fail — an unrecognised value becomes
/// `.unknown(raw)`, carrying the raw string verbatim (ARCHITECTURE §5).
enum EnumMapping {
  // MARK: - Closed enums (wire unknown-tolerant → domain strictly-closed, nil on out-of-set)

  // swiftlint:disable:next cyclomatic_complexity
  static func card(_ wire: WireEnum<WorkoutCard>) -> DomainModels.Card? {
    guard let known = wire.known else { return nil }
    switch known {
    case .easyRun: return .easyRun
    case .longRun: return .longRun
    case .progressionRun: return .progressionRun
    case .activeRecovery: return .activeRecovery
    case .threshold: return .threshold
    case .vo2: return .vo2
    case .strides: return .strides
    case .hiit: return .hiit
    case .jumpRope: return .jumpRope
    case .steadyCardio: return .steadyCardio
    case .strengthPush: return .strengthPush
    case .strengthPull: return .strengthPull
    case .strengthLower: return .strengthLower
    case .strengthFull: return .strengthFull
    case .boxing: return .boxing
    case .boxingTechnique: return .boxingTechnique
    case .footPrehab: return .footPrehab
    case .glutePrehab: return .glutePrehab
    case .mobility: return .mobility
    case .rest: return .rest
    }
  }

  static func zone(_ wire: WireEnum<WireModels.Zone>) -> DomainModels.Zone? {
    guard let known = wire.known else { return nil }
    switch known {
    case .z1: return .z1
    case .z2: return .z2
    case .z3: return .z3
    case .z4: return .z4
    case .z5: return .z5
    }
  }

  static func band(_ wire: WireEnum<WireModels.ReadinessBand>) -> DomainModels.ReadinessBand? {
    guard let known = wire.known else { return nil }
    switch known {
    case .green: return .green
    case .amber: return .amber
    case .red: return .red
    }
  }

  static func dayType(_ wire: WireEnum<WireModels.DayType>) -> DomainModels.DayType? {
    guard let known = wire.known else { return nil }
    switch known {
    case .hard: return .hard
    case .moderate: return .moderate
    case .rest: return .rest
    }
  }

  static func intensity(_ wire: WireEnum<WireModels.Intensity>) -> DomainModels.Intensity? {
    guard let known = wire.known else { return nil }
    switch known {
    case .easy: return .easy
    case .quality: return .quality
    case .recovery: return .recovery
    }
  }

  static func narrativeType(_ wire: WireEnum<WireModels.NarrativeType>) -> DomainModels.NarrativeType? {
    guard let known = wire.known else { return nil }
    switch known {
    case .summary: return .summary
    case .session: return .session
    case .nutrition: return .nutrition
    case .caution: return .caution
    case .plan: return .plan
    }
  }

  static func tier(_ wire: WireEnum<WireModels.Tier>) -> DomainModels.Tier? {
    guard let known = wire.known else { return nil }
    switch known {
    case .core: return .core
    case .extra: return .extra
    }
  }

  static func weekday(_ wire: WireEnum<WireModels.Weekday>) -> DomainModels.Weekday? {
    guard let known = wire.known else { return nil }
    switch known {
    case .mon: return .mon
    case .tue: return .tue
    case .wed: return .wed
    case .thu: return .thu
    case .fri: return .fri
    case .sat: return .sat
    case .sun: return .sun
    }
  }

  // MARK: - Free-string fields (never fail — unknown carries the raw string verbatim)

  // swiftlint:disable:next cyclomatic_complexity
  static func flag(_ raw: String) -> Flag {
    switch raw {
    case "impact": .impact
    case "needs_green_knee": .needsGreenKnee
    case "low_impact": .lowImpact
    case "prefer_low_impact": .preferLowImpact
    case "knee_amber_cap": .kneeAmberCap
    case "append_to_easy": .appendToEasy
    case "effort_based": .effortBased
    case "auto_reg_downgrade": .autoRegDowngrade
    case "big_recovery_cost": .bigRecoveryCost
    case "prehab:foot": .prehabFoot
    case "prehab:glute": .prehabGlute
    case "quality_day": .qualityDay
    default: .unknown(raw)
    }
  }

  static func safetyReason(_ raw: String) -> SafetyReason {
    switch raw {
    case "gi_flare": .giFlare
    case "illness": .illness
    case "knee_pain_high": .kneePainHigh
    case "sleep_below_4h": .sleepBelow4h
    case "rhr_spike": .rhrSpike
    case "hrv_crash": .hrvCrash
    default: .unknown(raw)
    }
  }

  static func penaltyFactor(_ raw: String) -> PenaltyFactor {
    switch raw {
    case "sleep_below_7h": .sleepBelow7h
    case "sleep_below_5h": .sleepBelow5h
    case "hrv_below_baseline": .hrvBelowBaseline
    case "rhr_above_baseline": .rhrAboveBaseline
    case "yesterday_hard_day": .yesterdayHardDay
    default: .unknown(raw)
    }
  }
}
