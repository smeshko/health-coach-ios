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
    case .giFlare: "GI Flare"
    case .illness: "Illness"
    case .kneePainHigh: "High Knee Pain"
    case .sleepBelow4h: "Sleep Below 4h"
    case .rhrSpike: "Resting HR Spike"
    case .hrvCrash: "HRV Crash"
    case let .unknown(raw): gracefulLabel(forUnknownRaw: raw)
    }
  }
}

extension PenaltyFactor: DisplayLabel {
  public var label: String {
    switch self {
    case .sleepBelow7h: "Sleep Below 7h"
    case .sleepBelow5h: "Sleep Below 5h"
    case .hrvBelowBaseline: "HRV Below Baseline"
    case .rhrAboveBaseline: "RHR Above Baseline"
    case .yesterdayHardDay: "Yesterday Was a Hard Day"
    case let .unknown(raw): gracefulLabel(forUnknownRaw: raw)
    }
  }
}
