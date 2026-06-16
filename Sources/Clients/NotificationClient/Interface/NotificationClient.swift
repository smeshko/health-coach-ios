import Dependencies

/// The local-notifications data source (ARCHITECTURE §6 / D21) — a `Sendable` struct of `@Sendable`
/// closures: request/read authorization and schedule/cancel/list **identified** local notifications.
/// The interface exposes only the hand-rolled value types (`NotificationRequest`/`NotificationTrigger`
/// /`NotificationDateComponents`/`NotificationAuthorizationStatus`); **no `UserNotifications` import**
/// crosses this boundary (§15) — `liveValue` lives in `NotificationClientLive`, and the
/// `testValue`/`previewValue` are framework-free. Hand-rolled struct (not `@DependencyClient`) to match
/// the sibling data-source clients (HealthKitClient/APIClient/TokenClient/LogClient).
public struct NotificationClient: Sendable {
  /// Requests alert + sound (+ badge) authorization and returns the resulting status.
  public var requestAuthorization: @Sendable () async throws -> NotificationAuthorizationStatus
  /// Reads the current authorization status (for the Settings surface / before scheduling).
  public var authorizationStatus: @Sendable () async -> NotificationAuthorizationStatus
  /// Adds (or overwrites, by `id`) one identified pending notification.
  public var schedule: @Sendable (_ request: NotificationRequest) async throws -> Void
  /// Removes pending notifications by identifier.
  public var cancel: @Sendable (_ ids: [String]) async -> Void
  /// The currently-scheduled identifiers (lets 10.3 / Settings reconcile state + supports assertions).
  public var pendingIdentifiers: @Sendable () async -> [String]

  public init(
    requestAuthorization: @escaping @Sendable () async throws -> NotificationAuthorizationStatus,
    authorizationStatus: @escaping @Sendable () async -> NotificationAuthorizationStatus,
    schedule: @escaping @Sendable (_ request: NotificationRequest) async throws -> Void,
    cancel: @escaping @Sendable (_ ids: [String]) async -> Void,
    pendingIdentifiers: @escaping @Sendable () async -> [String]
  ) {
    self.requestAuthorization = requestAuthorization
    self.authorizationStatus = authorizationStatus
    self.schedule = schedule
    self.cancel = cancel
    self.pendingIdentifiers = pendingIdentifiers
  }
}

extension NotificationClient: TestDependencyKey {
  /// Stubbed here so the interface compiles; the **recording** test value (which captures
  /// `schedule`/`cancel` calls for host tests + Epic 10.3's `TestStore`) is wired in TASK-002.
  public static var testValue: NotificationClient {
    NotificationClient(
      requestAuthorization: { .authorized },
      authorizationStatus: { .notDetermined },
      schedule: { _ in },
      cancel: { _ in },
      pendingIdentifiers: { [] }
    )
  }

  /// A benign always-`.authorized`, no-op value for SwiftUI previews (no recorder needed).
  public static var previewValue: NotificationClient {
    NotificationClient(
      requestAuthorization: { .authorized },
      authorizationStatus: { .authorized },
      schedule: { _ in },
      cancel: { _ in },
      pendingIdentifiers: { [] }
    )
  }
}

public extension DependencyValues {
  var notificationClient: NotificationClient {
    get { self[NotificationClient.self] }
    set { self[NotificationClient.self] = newValue }
  }
}
