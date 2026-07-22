/// A safety-gate reason (PRD §12.3) — why a session was overridden to rest/recovery.
///
/// Free-string on the wire; typed here with a `.unknown(String)` fallback (ARCHITECTURE §5). The
/// wire string ↔ case mapping lives **here** — single owner (Phase 20.1).
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

/// The single wire-string map (Phase 20.1). Adding a case → extend `wireString`'s switch
/// (compiler-enforced) AND `knownCases` (parity-tested by `WireStringParityTests`).
extension SafetyReason {
  /// All non-`unknown` cases, in declaration order.
  public static let knownCases: [SafetyReason] = [
    .giFlare, .illness, .kneePainHigh, .sleepBelow4h, .rhrSpike, .hrvCrash,
  ]

  /// Decode map derived from `knownCases` so decode and encode cannot diverge independently.
  private static let decodeMap: [String: SafetyReason] =
    Dictionary(uniqueKeysWithValues: knownCases.map { ($0.wireString, $0) })

  /// Map a raw wire string to its case, `.unknown(raw)` verbatim when unrecognised. Never fails.
  public init(wireString raw: String) {
    self = Self.decodeMap[raw] ?? .unknown(raw)
  }

  /// The canonical wire string for this case (`.unknown` carries its raw string verbatim).
  public var wireString: String {
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

/// Single-value raw-string persistence coding using the **wire strings** (DECISIONS D2 — normalizing,
/// not lossless for case-colliding `.unknown` strings; see `Flag` for the full rationale).
extension SafetyReason: Codable {
  public init(from decoder: Decoder) throws {
    self.init(wireString: try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wireString)
  }
}
