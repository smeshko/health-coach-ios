import Foundation

/// HTTP method (the two the API uses).
enum HTTPMethod: String, Sendable {
  case get = "GET"
  case post = "POST"
}

/// Per-endpoint retry policy. `.transientOnly` retries 502/504 with capped backoff; `.never` does not.
enum RetryPolicy: Sendable {
  case never
  case transientOnly
}

/// A phantom-typed route description (internal to `APIClientLive`). Per-endpoint policy lives here;
/// the cross-cutting transport (auth, retry, 401 stream, envelope decode) lives once in `send`
/// (ARCHITECTURE §6.1).
struct Endpoint<Response: Decodable & Sendable>: Sendable {
  var method: HTTPMethod = .post
  var path: String
  var query: [URLQueryItem] = []
  /// Throwing so a body-encode failure surfaces as a thrown error, never a `try!` (§6.1).
  var body: (@Sendable () throws -> Data)?
  var retry: RetryPolicy = .transientOnly
  var timeout: Duration = .seconds(60)
  var requiresAuth = true
}
