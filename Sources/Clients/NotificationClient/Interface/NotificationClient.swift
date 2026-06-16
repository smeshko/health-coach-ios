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
  /// A **recording** test value: `schedule`/`cancel`/`pendingIdentifiers` route through one shared
  /// `RecordingNotificationCenter` so host tests can assert what was scheduled/cancelled — **without
  /// touching `UserNotifications`**. Authorization is canned `.authorized`. To read the recorder back
  /// in a test, build the value via `NotificationClient.recording()` (which returns the recorder too).
  public static var testValue: NotificationClient {
    recording().client
  }

  /// Builds a recording `NotificationClient` paired with the `RecordingNotificationCenter` its closures
  /// route through, so a host test / `TestStore` can drive `schedule`/`cancel` and then assert via the
  /// recorder's read accessors (or `pendingIdentifiers()`).
  public static func recording() -> (client: NotificationClient, recorder: RecordingNotificationCenter) {
    let recorder = RecordingNotificationCenter()
    let client = NotificationClient(
      requestAuthorization: { .authorized },
      authorizationStatus: { .authorized },
      // Validate up-front, exactly as `NotificationClientLive` does, so a TestStore can't record a
      // schedule production would reject (review #2.1).
      schedule: { request in
        try request.trigger.validate()
        await recorder.schedule(request)
      },
      cancel: { await recorder.cancel($0) },
      pendingIdentifiers: { await recorder.pendingIdentifiers() }
    )
    return (client, recorder)
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
