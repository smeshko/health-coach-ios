/// A safety-gate reason (PRD §12.3) — why a session was overridden to rest/recovery.
///
/// Free-string on the wire; typed here with a `.unknown(String)` fallback (ARCHITECTURE §5).
public enum SafetyReason: Sendable, Hashable {
  case giFlare
  case illness
  case kneePainHigh
  case sleepBelow4h
  case rhrSpike
  case hrvCrash
  /// An unrecognised wire reason, raw string preserved verbatim.
  case unknown(String)
}

/// Single-value raw-string persistence coding using the **wire strings** (DECISIONS D2 — normalizing,
/// not lossless for case-colliding `.unknown` strings; see `Flag` for the full rationale).
extension SafetyReason: Codable {
  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    switch raw {
    case "gi_flare": self = .giFlare
    case "illness": self = .illness
    case "knee_pain_high": self = .kneePainHigh
    case "sleep_below_4h": self = .sleepBelow4h
    case "rhr_spike": self = .rhrSpike
    case "hrv_crash": self = .hrvCrash
    default: self = .unknown(raw)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wireString)
  }

  private var wireString: String {
    switch self {
    case .giFlare: "gi_flare"
    case .illness: "illness"
    case .kneePainHigh: "knee_pain_high"
    case .sleepBelow4h: "sleep_below_4h"
    case .rhrSpike: "rhr_spike"
    case .hrvCrash: "hrv_crash"
    case let .unknown(raw): raw
    }
  }
}
