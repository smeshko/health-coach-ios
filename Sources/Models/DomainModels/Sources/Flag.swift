/// A session flag (PRD §12.2) — a machine key the backend attaches to a session.
///
/// Free-string on the wire; the domain types it with a `.unknown(String)` fallback so a new backend
/// flag never fails a brief (ARCHITECTURE §5). The raw wire string ↔ case mapping lives **here** —
/// this file is its single owner (Phase 20.1); UX labels live in `DesignSystem` (Epic 05).
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

/// The single wire-string map (Phase 20.1). Adding a case → extend `wireString`'s switch
/// (compiler-enforced) AND `knownCases` (parity-tested by `WireStringParityTests`).
extension Flag {
  /// All non-`unknown` cases, in declaration order.
  public static let knownCases: [Flag] = [
    .impact, .needsGreenKnee, .lowImpact, .preferLowImpact, .kneeAmberCap, .appendToEasy,
    .effortBased, .autoRegDowngrade, .bigRecoveryCost, .prehabFoot, .prehabGlute, .qualityDay,
  ]

  /// Decode map derived from `knownCases` so decode and encode cannot diverge independently.
  private static let decodeMap: [String: Flag] =
    Dictionary(uniqueKeysWithValues: knownCases.map { ($0.wireString, $0) })

  /// Map a raw wire string to its case, `.unknown(raw)` verbatim when unrecognised. Never fails.
  public init(wireString raw: String) {
    self = Self.decodeMap[raw] ?? .unknown(raw)
  }

  /// The canonical wire string for this case (`.unknown` carries its raw string verbatim).
  public var wireString: String {
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

/// Single-value raw-string persistence coding using the **wire strings** as the canonical
/// representation (so Phase 11.3's enum sharing needs no second format change). Encode a known case
/// to its wire string, `.unknown(raw)` verbatim; decode a matched wire string to its case, else
/// `.unknown(raw)`. Normalizing, not lossless: `.unknown("quality_day")` round-trips to `.qualityDay`
/// (DECISIONS D2 — no fixture or production path produces a case-colliding `.unknown`).
extension Flag: Codable {
  public init(from decoder: Decoder) throws {
    self.init(wireString: try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wireString)
  }
}
