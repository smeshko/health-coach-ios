/// A readiness penalty factor (PRD §12.3) — what docked readiness points.
///
/// Free-string on the wire; typed here with a `.unknown(String)` fallback (ARCHITECTURE §5).
public enum PenaltyFactor: Sendable, Hashable {
  case sleepBelow7h
  case sleepBelow5h
  case hrvBelowBaseline
  case rhrAboveBaseline
  case yesterdayHardDay
  /// An unrecognised wire factor, raw string preserved verbatim.
  case unknown(String)
}

/// Single-value raw-string persistence coding using the **wire strings** (DECISIONS D2 — normalizing,
/// not lossless for case-colliding `.unknown` strings; see `Flag` for the full rationale).
extension PenaltyFactor: Codable {
  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    switch raw {
    case "sleep_below_7h": self = .sleepBelow7h
    case "sleep_below_5h": self = .sleepBelow5h
    case "hrv_below_baseline": self = .hrvBelowBaseline
    case "rhr_above_baseline": self = .rhrAboveBaseline
    case "yesterday_hard_day": self = .yesterdayHardDay
    default: self = .unknown(raw)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wireString)
  }

  private var wireString: String {
    switch self {
    case .sleepBelow7h: "sleep_below_7h"
    case .sleepBelow5h: "sleep_below_5h"
    case .hrvBelowBaseline: "hrv_below_baseline"
    case .rhrAboveBaseline: "rhr_above_baseline"
    case .yesterdayHardDay: "yesterday_hard_day"
    case let .unknown(raw): raw
    }
  }
}
