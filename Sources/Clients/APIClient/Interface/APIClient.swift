import Dependencies
import Foundation
import WireModels

/// The network client — a `Sendable` struct of **concrete** typed closures (the generic `send<R>`
/// transport stays internal to `APIClientLive`; swift-dependencies stored closures can't be generic,
/// §6.1). Features/repositories depend only on this interface.
public struct APIClient: Sendable {
  public var probe: @Sendable () async throws -> Bool
  public var sync: @Sendable (SyncRequest) async throws -> SyncResponse
  public var dailyBrief: @Sendable (_ date: Date?, _ refresh: Bool) async throws -> DailyBrief
  public var weeklyBrief: @Sendable (_ isoWeek: String?, _ refresh: Bool) async throws -> WeeklyPlan
  public var profile: @Sendable () async throws -> ProfileResponse
  /// The 401 / session-event stream `AppFeature` subscribes to (Epic 06). By design there is exactly
  /// **one** consumer (`AppFeature`'s long-running effect): the live client returns a single shared
  /// `AsyncStream`, so iterating it from more than one place would split events arbitrarily
  /// (DECISIONS §3).
  public var sessionEvents: @Sendable () -> AsyncStream<SessionEvent>

  public init(
    probe: @escaping @Sendable () async throws -> Bool,
    sync: @escaping @Sendable (SyncRequest) async throws -> SyncResponse,
    dailyBrief: @escaping @Sendable (_ date: Date?, _ refresh: Bool) async throws -> DailyBrief,
    weeklyBrief: @escaping @Sendable (_ isoWeek: String?, _ refresh: Bool) async throws -> WeeklyPlan,
    profile: @escaping @Sendable () async throws -> ProfileResponse,
    sessionEvents: @escaping @Sendable () -> AsyncStream<SessionEvent>
  ) {
    self.probe = probe
    self.sync = sync
    self.dailyBrief = dailyBrief
    self.weeklyBrief = weeklyBrief
    self.profile = profile
    self.sessionEvents = sessionEvents
  }
}

public extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClient.self] }
    set { self[APIClient.self] = newValue }
  }
}
