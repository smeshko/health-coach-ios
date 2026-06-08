import APIClient
import Dependencies
import Foundation
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

  /// Capped exponential backoff schedule (~63 s total ≈ the ~60 s cap). One sleep per retry.
  private static let backoff: [Duration] = [
    .seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(16), .seconds(32),
  ]

  func send<R: Decodable & Sendable>(_ endpoint: Endpoint<R>) async throws -> R {
    @Dependency(\.tokenClient) var dependencyToken
    @Dependency(\.continuousClock) var clock
    let tokenClient = tokenClientOverride ?? dependencyToken

    var retryCount = 0
    while true {
      let bearer = endpoint.requiresAuth ? try await tokenClient.read() : nil
      let request = try urlRequest(for: endpoint, baseURL: baseURL, bearer: bearer)

      let data: Data
      let response: URLResponse
      do {
        (data, response) = try await session.data(for: request)
      } catch let error as URLError {
        throw APIError.transport(error.localizedDescription)
      }

      guard let http = response as? HTTPURLResponse else {
        throw APIError.transport("Non-HTTP response")
      }
      let status = http.statusCode

      // 401 first — yield then throw, never decode the envelope, never retry (§13/§12).
      if status == 401 {
        continuation.yield(.unauthorized)
        throw APIError.unauthorized
      }

      if (200 ..< 300).contains(status) {
        do {
          return try WireCoder.decoder.decode(R.self, from: data)
        } catch {
          throw APIError.decoding(String(describing: error))
        }
      }

      // Retry only 502/504, only when the route opts in, only up to the cap.
      let isTransientStatus = status == 502 || status == 504
      if isTransientStatus, endpoint.retry == .transientOnly, retryCount < Self.backoff.count {
        try await clock.sleep(for: Self.backoff[retryCount])
        retryCount += 1
        continue
      }

      // Other non-2xx (incl. exhausted retries): decode the envelope, else unexpected status.
      if let envelope = try? WireCoder.decoder.decode(ErrorResponse.self, from: data) {
        throw APIError(envelope: envelope, status: status)
      }
      throw APIError.unexpectedStatus(status)
    }
  }
}
