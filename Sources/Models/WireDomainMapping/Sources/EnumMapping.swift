import DomainModels

/// The raw-string ↔ typed-enum maps. Pure, non-throwing leaf helpers.
///
/// The closed enums are now SHARED between the wire and domain layers (Phase 11.3) — a wire DTO
/// field already holds the `DomainModels` type. The closed-enum helpers below are therefore trivial
/// identity pass-throughs returning an optional (kept optional so the shape mappers' existing
/// `guard let` / `flatMap` call sites are untouched; a later task removes them entirely). Free-string
/// helpers never fail — an unrecognised value becomes `.unknown(raw)`, carrying the raw string
/// verbatim (ARCHITECTURE §5).
enum EnumMapping {
  // MARK: - Closed enums (now shared wire↔domain → identity pass-through)

  static func card(_ value: DomainModels.Card) -> DomainModels.Card? { value }

  static func zone(_ value: DomainModels.Zone) -> DomainModels.Zone? { value }

  static func band(_ value: DomainModels.ReadinessBand) -> DomainModels.ReadinessBand? { value }

  static func dayType(_ value: DomainModels.DayType) -> DomainModels.DayType? { value }

  static func intensity(_ value: DomainModels.Intensity) -> DomainModels.Intensity? { value }

  static func narrativeType(_ value: DomainModels.NarrativeType) -> DomainModels.NarrativeType? { value }

  static func tier(_ value: DomainModels.Tier) -> DomainModels.Tier? { value }

  static func weekday(_ value: DomainModels.Weekday) -> DomainModels.Weekday? { value }

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
