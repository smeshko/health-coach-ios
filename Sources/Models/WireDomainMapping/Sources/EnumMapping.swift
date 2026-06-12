import DomainModels

/// The raw-string → open-enum maps for the three free-string fields (`flag`, `safetyReason`,
/// `penaltyFactor`). Pure, non-throwing leaf helpers — they never fail: an unrecognised value
/// becomes `.unknown(raw)`, carrying the raw string verbatim (ARCHITECTURE §5).
///
/// The closed enums are SHARED between the wire and domain layers (Phase 11.3) — a wire DTO field
/// already holds the `DomainModels` type, so no closed-enum mapping is needed; the shape mappers use
/// those fields directly.
enum EnumMapping {
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
