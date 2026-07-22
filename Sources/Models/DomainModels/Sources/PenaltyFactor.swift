/// A readiness penalty factor (PRD §12.3) — what docked readiness points.
///
/// Free-string on the wire; typed here with a `.unknown(String)` fallback (ARCHITECTURE §5). The
/// wire string ↔ case mapping lives **here** — single owner (Phase 20.1).
public enum PenaltyFactor: Sendable, Hashable {
  case sleepBelow7h
  case sleepBelow5h
  case hrvBelowBaseline
  case rhrAboveBaseline
  case yesterdayHardDay
  /// An unrecognised wire factor, raw string preserved verbatim.
  case unknown(String)
}

/// The single wire-string map (Phase 20.1). Adding a case → extend `wireString`'s switch
/// (compiler-enforced) AND `knownCases` (parity-tested by `WireStringParityTests`).
extension PenaltyFactor {
  /// All non-`unknown` cases, in declaration order.
  public static let knownCases: [PenaltyFactor] = [
    .sleepBelow7h, .sleepBelow5h, .hrvBelowBaseline, .rhrAboveBaseline, .yesterdayHardDay,
  ]

  /// Decode map derived from `knownCases` so decode and encode cannot diverge independently.
  private static let decodeMap: [String: PenaltyFactor] =
    Dictionary(uniqueKeysWithValues: knownCases.map { ($0.wireString, $0) })

  /// Map a raw wire string to its case, `.unknown(raw)` verbatim when unrecognised. Never fails.
  public init(wireString raw: String) {
    self = Self.decodeMap[raw] ?? .unknown(raw)
  }

  /// The canonical wire string for this case (`.unknown` carries its raw string verbatim).
  public var wireString: String {
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

/// Single-value raw-string persistence coding using the **wire strings** (DECISIONS D2 — normalizing,
/// not lossless for case-colliding `.unknown` strings; see `Flag` for the full rationale).
extension PenaltyFactor: Codable {
  public init(from decoder: Decoder) throws {
    self.init(wireString: try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wireString)
  }
}
