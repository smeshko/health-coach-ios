/// A session flag (PRD §12.2) — a machine key the backend attaches to a session.
///
/// Free-string on the wire; the domain types it with a `.unknown(String)` fallback so a new backend
/// flag never fails a brief (ARCHITECTURE §5). The raw wire string ↔ case mapping lives in
/// `WireDomainMapping`, never here; UX labels live in `DesignSystem` (Epic 05).
public enum Flag: Sendable, Hashable {
  case impact
  case needsGreenKnee
  case lowImpact
  case preferLowImpact
  case kneeAmberCap
  case appendToEasy
  case effortBased
  case autoRegDowngrade
  case bigRecoveryCost
  case prehabFoot
  case prehabGlute
  case qualityDay
  /// An unrecognised wire flag, raw string preserved verbatim.
  case unknown(String)
}

/// Single-value raw-string persistence coding using the **wire strings** as the canonical
/// representation (so Phase 11.3's enum sharing needs no second format change). Encode a known case
/// to its wire string, `.unknown(raw)` verbatim; decode a matched wire string to its case, else
/// `.unknown(raw)`. Normalizing, not lossless: `.unknown("quality_day")` round-trips to `.qualityDay`
/// (DECISIONS D2 — no fixture or production path produces a case-colliding `.unknown`).
extension Flag: Codable {
  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    switch raw {
    case "impact": self = .impact
    case "needs_green_knee": self = .needsGreenKnee
    case "low_impact": self = .lowImpact
    case "prefer_low_impact": self = .preferLowImpact
    case "knee_amber_cap": self = .kneeAmberCap
    case "append_to_easy": self = .appendToEasy
    case "effort_based": self = .effortBased
    case "auto_reg_downgrade": self = .autoRegDowngrade
    case "big_recovery_cost": self = .bigRecoveryCost
    case "prehab:foot": self = .prehabFoot
    case "prehab:glute": self = .prehabGlute
    case "quality_day": self = .qualityDay
    default: self = .unknown(raw)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wireString)
  }

  private var wireString: String {
    switch self {
    case .impact: "impact"
    case .needsGreenKnee: "needs_green_knee"
    case .lowImpact: "low_impact"
    case .preferLowImpact: "prefer_low_impact"
    case .kneeAmberCap: "knee_amber_cap"
    case .appendToEasy: "append_to_easy"
    case .effortBased: "effort_based"
    case .autoRegDowngrade: "auto_reg_downgrade"
    case .bigRecoveryCost: "big_recovery_cost"
    case .prehabFoot: "prehab:foot"
    case .prehabGlute: "prehab:glute"
    case .qualityDay: "quality_day"
    case let .unknown(raw): raw
    }
  }
}
