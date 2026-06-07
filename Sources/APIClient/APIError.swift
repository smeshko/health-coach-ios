import Foundation
import WireModels

/// A typed transport/wire error surfaced by `APIClient`. Lives in the **interface** target so Epic
/// 04 repositories can map it to domain errors while depending only on the interface (§14/D14).
public enum APIError: Error, Sendable, Equatable {
  /// A non-2xx (other than 401) whose body was the wire error envelope. Carries the (unknown-tolerant)
  /// wire `code`, the safe `message`, optional `detail`, and the HTTP `status`.
  case envelope(code: WireEnum<ErrorCode>, message: String, detail: String?, status: Int)
  /// A 401 — handled by status before any envelope decode (yields `.unauthorized` on the session
  /// stream, no retry).
  case unauthorized
  /// A `URLError` / network failure (description captured for `Sendable` equality).
  case transport(String)
  /// A 2xx body that failed to decode into the expected DTO.
  case decoding(String)
  /// A non-2xx body that was not the error envelope (or was empty).
  case unexpectedStatus(Int)

  /// Build the `.envelope` case from a decoded wire `ErrorResponse` + the HTTP status.
  public init(envelope: ErrorResponse, status: Int) {
    self = .envelope(
      code: envelope.error.code,
      message: envelope.error.message,
      detail: envelope.error.detail,
      status: status
    )
  }
}
