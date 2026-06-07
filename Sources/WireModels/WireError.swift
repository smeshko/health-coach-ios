import Foundation

/// The error envelope wrapper (`openapi.yaml` `ErrorResponse`). The JSON key is `error`.
public struct ErrorResponse: Codable, Sendable, Equatable {
  public var error: WireError

  public init(error: WireError) {
    self.error = error
  }
}

/// The wire error body (`openapi.yaml` `Error`).
///
/// Named `WireError` — **not** `Error` — to avoid shadowing the stdlib `Error` protocol; the JSON
/// key stays `error` (owned by ``ErrorResponse``). Decoding non-2xx bodies into an `APIError` is
/// Epic 03; this phase only *defines* the envelope.
public struct WireError: Codable, Sendable, Equatable {
  public var code: WireEnum<ErrorCode>
  public var message: String
  public var detail: String?

  public init(code: WireEnum<ErrorCode>, message: String, detail: String? = nil) {
    self.code = code
    self.message = message
    self.detail = detail
  }
}
