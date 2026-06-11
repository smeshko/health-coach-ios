import DomainModels

// Open-enum label conformances — exhaustive over known cases plus an `.unknown(raw)` arm that produces
// a graceful human label (never the raw key) (PRD §12.2/§12.3).

extension Flag: DisplayLabel {
  public var label: String {
    switch self {
    case .impact: "Impact"
    case .needsGreenKnee: "Needs Green Knee"
    case .lowImpact: "Low Impact"
    case .preferLowImpact: "Prefer Low Impact"
    case .kneeAmberCap: "Knee Amber Cap"
    case .appendToEasy: "Append to Easy"
    case .effortBased: "Effort-Based"
    case .autoRegDowngrade: "Auto-Reg Downgrade"
    case .bigRecoveryCost: "Big Recovery Cost"
    case .prehabFoot: "Foot Prehab"
    case .prehabGlute: "Glute Prehab"
    case .qualityDay: "Quality Day"
    case let .unknown(raw): gracefulLabel(forUnknownRaw: raw)
    }
  }
}

extension SafetyReason: DisplayLabel {
  public var label: String {
    switch self {
    case .giFlare: "Gut flare"
    case .illness: "Feeling unwell"
    case .kneePainHigh: "Knee pain high"
    case .sleepBelow4h: "Very little sleep"
    case .rhrSpike: "Resting HR spike"
    case .hrvCrash: "HRV drop"
    case let .unknown(raw): gracefulLabel(forUnknownRaw: raw)
    }
  }
}

extension PenaltyFactor: DisplayLabel {
  public var label: String {
    switch self {
    case .sleepBelow7h: "Short sleep"
    case .sleepBelow5h: "Very short sleep"
    case .hrvBelowBaseline: "HRV below baseline"
    case .rhrAboveBaseline: "Resting HR elevated"
    case .yesterdayHardDay: "Hard session yesterday"
    case let .unknown(raw): gracefulLabel(forUnknownRaw: raw)
    }
  }
}
