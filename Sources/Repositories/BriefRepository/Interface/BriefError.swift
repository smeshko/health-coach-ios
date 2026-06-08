/// The domain error a `BriefRepository` surfaces. Lives in the **interface** target so features and
/// the repo both see it without importing `*Live` or `APIClient` (DECISIONS #1). Cases are
/// payload-free: the Epic 05 `ErrorPresenter` keys off the case for §8.3/§12 copy + retry
/// affordances. Each case documents the §12 row it maps from.
public enum BriefError: Error, Equatable, Sendable {
  /// No cached brief for today and no successful prior sync — the user must sync first (§8.5/§12).
  case syncRequired
  /// A transient generation failure (`502 brief_generation_failed` / `504 upstream_timeout`) or a
  /// transport/offline failure — block-and-retry, no hammering (§12, D23/§14).
  case transientGenerationFailed
  /// A `500 internal_error` on a **first-ever** brief (no brief ever cached) — "sync your health data
  /// first" (§8.5/§12).
  case insufficientData
  /// A `422 validation_error` (§12).
  case validation
  /// A `500 internal_error` with a prior brief present, a `404 not_found`, or any other envelope code
  /// — the generic "log as a bug, offer Retry" state (§12 catch-all).
  case serverError
  /// A `401 unauthorized` — handled upstream via the session-event stream, mapped here for
  /// completeness (§12).
  case unauthorized
  /// A `WireDomainMapping.MappingError` — a malformed required closed enum surfaced as a domain error,
  /// never a crash (ARCHITECTURE §5).
  case mappingFailed
}
