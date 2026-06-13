import APIClient
import Dependencies
import Foundation
import LogClient
import TokenClient
import WireModels

/// The single generic executor behind every typed `APIClient` closure. Owns the session-event
/// stream and does the cross-cutting work once (ARCHITECTURE §6.1): bearer-header injection, the
/// 401→`.unauthorized` emission (no retry), 502/504 capped-backoff retry for brief routes, and
/// error-envelope → `APIError` decoding.
struct Transport: Sendable {
  let baseURL: URL
  let session: URLSession
  /// Explicit override for tests; when `nil`, `send` resolves `@Dependency(\.tokenClient)`.
  let tokenClientOverride: TokenClient?
  let sessionEvents: AsyncStream<SessionEvent>
  private let continuation: AsyncStream<SessionEvent>.Continuation

  init(baseURL: URL, session: URLSession, tokenClient: TokenClient?) {
    self.baseURL = baseURL
    self.session = session
    tokenClientOverride = tokenClient
    // Default `.unbounded` buffering retains a 401 yielded before the consumer iterates (Decision 3).
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    sessionEvents = stream
    self.continuation = continuation
  }

  /// Capped exponential backoff schedule (~7 s total worst case). One sleep per retry — 3 retries, so
  /// a transient 502/504 on a brief route gives up after ~7 s instead of silently waiting ~63 s.
  private static let backoff: [Duration] = [
    .seconds(1), .seconds(2), .seconds(4),
  ]

  func send<R: Decodable & Sendable>(_ endpoint: Endpoint<R>) async throws -> R {
    @Dependency(\.tokenClient) var dependencyToken
    @Dependency(\.continuousClock) var clock
    @Dependency(\.log) var log
    let tokenClient = tokenClientOverride ?? dependencyToken

    var retryCount = 0
    while true {
      let bearer = try await tokenClient.read()
      let request = try urlRequest(for: endpoint, baseURL: baseURL, bearer: bearer)
      logRequest(request, endpoint: endpoint, log)

      let data: Data
      let response: URLResponse
      do {
        (data, response) = try await session.data(for: request)
      } catch let error as URLError {
        throw logged(.transport(error.localizedDescription), endpoint.path, log)
      }

      guard let http = response as? HTTPURLResponse else {
        throw logged(.transport("Non-HTTP response"), endpoint.path, log)
      }
      let status = http.statusCode
      log.info("response \(status) \(endpoint.path)", category: .http, metadata: [
        "status": "\(status)", "body": Self.bodyString(data),
      ])

      // 401 first — yield then throw, never decode the envelope, never retry (§13/§12).
      if status == 401 {
        log.notice("unauthorized \(endpoint.path) — emitted .unauthorized", category: .http)
        continuation.yield(.unauthorized)
        throw APIError.unauthorized
      }

      if (200 ..< 300).contains(status) {
        do {
          return try WireCoder.decoder.decode(R.self, from: data)
        } catch {
          throw logged(.decoding(String(describing: error)), endpoint.path, log)
        }
      }

      // Retry only 502/504, only when the route opts in, only up to the cap.
      let isTransientStatus = status == 502 || status == 504
      if isTransientStatus, endpoint.retry == .transientOnly, retryCount < Self.backoff.count {
        let delay = Self.backoff[retryCount]
        log.notice("retry \(retryCount + 1) status \(status) \(endpoint.path) backoff \(delay)", category: .http)
        try await clock.sleep(for: delay)
        retryCount += 1
        continue
      }

      // Other non-2xx (incl. exhausted retries): decode the envelope, else unexpected status.
      if let envelope = try? WireCoder.decoder.decode(ErrorResponse.self, from: data) {
        throw logged(APIError(envelope: envelope, status: status), endpoint.path, log)
      }
      throw logged(.unexpectedStatus(status), endpoint.path, log)
    }
  }

  /// Log the outgoing request with the bearer redacted (the single redaction site, DECISIONS 4).
  private func logRequest(_ request: URLRequest, endpoint: Endpoint<some Any>, _ log: LogClient) {
    log.info("request \(endpoint.method.rawValue) \(endpoint.path)", category: .http, metadata: [
      "url": request.url?.absoluteString ?? endpoint.path,
      "headers": Self.redactedHeaders(request),
      "body": Self.bodyString(request.httpBody),
    ])
  }

  /// Log `apiError` under `.http` and hand it back to `throw` — keeps the throw sites one line each.
  private func logged(_ apiError: APIError, _ path: String, _ log: LogClient) -> APIError {
    log.error("error \(path): \(apiError)", category: .http)
    return apiError
  }

  /// Render the request headers for logging with the `Authorization` bearer masked — the credential
  /// is materialised only here, so this is the exact, single redaction site (DECISIONS 4). Bodies are
  /// logged in full; only the bearer is sensitive.
  private static func redactedHeaders(_ request: URLRequest) -> String {
    let headers = request.allHTTPHeaderFields ?? [:]
    return headers
      .map { key, value in
        let shown = key.lowercased() == "authorization" ? "Bearer <redacted>" : value
        return "\(key)=\(shown)"
      }
      .sorted()
      .joined(separator: "; ")
  }

  private static func bodyString(_ data: Data?) -> String {
    guard let data, !data.isEmpty else { return "<empty>" }
    return String(bytes: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
  }
}
