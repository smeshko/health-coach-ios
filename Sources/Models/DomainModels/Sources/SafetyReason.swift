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
