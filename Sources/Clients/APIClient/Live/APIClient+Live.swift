import APIClient
import Dependencies
import Foundation
import TokenClient

public extension APIClient {
  /// Construct a live client over a `Transport`. Injectable for tests (`session` = a URLProtocol-
  /// stubbed session, `tokenClient` = an in-memory store).
  static func live(
    baseURL: URL = URL(string: "http://localhost:8000")!,
    session: URLSession = .shared,
    tokenClient: TokenClient? = nil
  ) -> APIClient {
    let transport = Transport(baseURL: baseURL, session: session, tokenClient: tokenClient)
    return APIClient(
      // /probe returns a bare `[String: Bool]`; Connect only needs reachable+authed → 200 ⇒ true
      // (a 401 throws `.unauthorized` from `send` and emits on the stream).
      probe: {
        _ = try await transport.send(Routes.probe)
        return true
      },
      sync: { try await transport.send(Routes.sync($0)) },
      dailyBrief: { try await transport.send(Routes.dailyBrief(date: $0, refresh: $1)) },
      weeklyBrief: { try await transport.send(Routes.weeklyBrief(isoWeek: $0, refresh: $1)) },
      profile: { try await transport.send(Routes.profile) },
      sessionEvents: { transport.sessionEvents }
    )
  }
}

extension APIClient: DependencyKey {
  public static var liveValue: APIClient { live() }
}
