import APIClient
import BriefRepository
import WireModels

/// Map a transport/wire `APIError` to a domain `BriefError` (PRD §8.3 / §12). Takes the **whole**
/// `APIError` (not just the `ErrorCode`) so the transport branch can be distinguished from an
/// envelope error (DECISIONS #5).
///
/// - Parameter hasPriorBrief: whether any brief of this kind has ever been cached — the `500
///   internal_error` fork (`.insufficientData` on a first-ever brief, else `.serverError`, §12).
func briefError(from apiError: APIError, hasPriorBrief: Bool) -> BriefError {
  switch apiError {
  case let .envelope(code, _, _, _):
    switch code.known {
    case .briefGenerationFailed, .upstreamTimeout:
      .transientGenerationFailed
    case .internalError:
      hasPriorBrief ? .serverError : .insufficientData
    case .validationError:
      .validation
    case .unauthorized:
      .unauthorized
    // `404 not_found` and any unrecognised (`.unknown` → `code.known == nil`) envelope code → the
    // generic catch-all (§12).
    case .notFound, .none:
      .serverError
    }
  case .unauthorized:
    .unauthorized
  // Transport branch (network unreachable / decode failure / empty-non-envelope non-2xx) → the
  // retry-friendly offline state, NOT `.serverError` (D23/§14, DECISIONS #5).
  case .transport, .decoding, .unexpectedStatus:
    .transientGenerationFailed
  }
}
