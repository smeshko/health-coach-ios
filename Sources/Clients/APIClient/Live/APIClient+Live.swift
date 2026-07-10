import APIClient
import Dependencies
import Foundation
import TokenClient

public extension APIClient {
  /// Construct a live client over a `Transport`. The base URL is **required** (CR-1: no shipped
  /// localhost default) — the composition root injects it explicitly, or `liveValue` resolves it
  /// via `APIBaseURL`. Injectable for tests (`session` = a URLProtocol-stubbed session,
  /// `tokenClient` = an in-memory store).
  static func live(
    baseURL: URL,
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

  /// The client installed when no base URL resolves: every request throws a clear configuration
  /// `APIError.transport` at first use (loud, recoverable — never a silent localhost target, and
  /// never a `fatalError`, because `routed()` factories construct live clients eagerly even in
  /// mock mode). `sessionEvents` finishes immediately so its single consumer never hangs.
  static let unconfigured: APIClient = {
    let error = APIError.transport(
      "API base URL not configured — set API_BASE_URL in the CoachApp build settings"
    )
    return APIClient(
      probe: { throw error },
      sync: { _ in throw error },
      dailyBrief: { _, _ in throw error },
      weeklyBrief: { _, _ in throw error },
      profile: { throw error },
      sessionEvents: { AsyncStream { $0.finish() } }
    )
  }()
}

extension APIClient: DependencyKey {
  /// Resolution chain (CR-1): explicit composition-root injection (`$0.apiClient =
  /// .live(baseURL:)`) wins; this default resolves the `APIBaseURL` Info.plist key via
  /// `APIBaseURL.resolve(bundle:)` (localhost fallback only on DEBUG + simulator); an
  /// unresolvable configuration yields the throwing `.unconfigured` client — never a trap.
  public static var liveValue: APIClient {
    APIBaseURL.resolve(bundle: .main).map { live(baseURL: $0) } ?? .unconfigured
  }
}
