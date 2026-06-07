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
