import APIClient
import SyncRepository
import WireModels

/// Map the wire `SyncResponse` to the domain `SyncResult` (a 200 — incl. all-zero counts — is success).
func syncResult(_ response: SyncResponse) -> SyncResult {
  SyncResult(
    recordsUpserted: response.recordsUpserted,
    recordsDuplicate: response.recordsDuplicate,
    workoutsUpserted: response.workoutsUpserted,
    activityDaysUpserted: response.activityDaysUpserted,
    checkinSaved: response.checkinSaved,
    strengthTestSaved: response.strengthTestSaved,
    serverTime: response.serverTime
  )
}

/// Map a `/sync` `APIError` to a domain `SyncError` (PRD §12). The `default:` arms guarantee no code is
/// unmapped. **401 is NOT mapped here** — the orchestration intercepts it and re-throws the raw
/// `APIError` (session-stream-handled, §13); `isUnauthorized(_:)` detects it.
func syncError(_ error: APIError) -> SyncError {
  switch error {
  case let .envelope(code, _, _, _):
    switch code {
    case .validationError: .validationFailed
    case .internalError: .serverError
    // 502/504 reach the repo (/sync is not transport-retried, 3.1) → retry-friendly transient.
    case .briefGenerationFailed, .upstreamTimeout: .transient
    // notFound / unauthorized (intercepted upstream) → transient default.
    default: .transient
    }
  case .transport:
    .network
  case .decoding:
    .mappingFailed
  case .unexpectedStatus:
    .transient
  case .unauthorized:
    // Intercepted upstream before this is called; defined for switch totality.
    .transient
  }
}

/// Whether an `APIError` is a 401 (a bare `.unauthorized` or an envelope with `code == .unauthorized`).
/// The orchestration re-throws these as-is so the session-event stream handles them (§13).
func isUnauthorized(_ error: APIError) -> Bool {
  switch error {
  case .unauthorized:
    true
  case let .envelope(code, _, _, _):
    code == .unauthorized
  default:
    false
  }
}
