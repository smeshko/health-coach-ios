/// The domain error a `SyncRepository` surfaces (PRD §8.3 / §12). Maps the `/sync`-relevant `APIError`
/// cases to a domain concern (D14). `401 unauthorized` is **intentionally absent** — it is handled by
/// the session-event stream in `APIClientLive` / `AppFeature` (§13), not surfaced here.
public enum SyncError: Error, Equatable, Sendable {
  /// `422 validation_error` — a malformed payload (a bug, §8.3).
  case validationFailed
  /// `500 internal_error` — a server fault.
  case serverError
  /// `502 brief_generation_failed` / `504 upstream_timeout` — these reach the repo because `/sync` is
  /// **not** transport-retried (502/504 retry is briefs-only, 3.1). The caller may safely re-invoke
  /// `sync()` (the watermark only advances on success). Also the `default:` fallback for any unmapped
  /// non-2xx (most plausibly a transient server/transport condition).
  case transient
  /// A network/transport failure (unreachable, timeout at the URL layer).
  case network
  /// A 2xx body that failed to decode, or a malformed response/payload.
  case mappingFailed
}
