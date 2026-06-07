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
