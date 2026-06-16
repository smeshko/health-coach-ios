/// An interface-local, framework-free recorder that captures `schedule`/`cancel` calls in process so
/// host tests (and Epic 10.3's `TestStore`) can drive the `NotificationClient` test value and read
/// back what was scheduled/cancelled — **without importing or touching `UserNotifications`** (the
/// epic's "the test value RECORDS scheduling calls without touching the system" AC).
///
/// An `actor` (rather than a `LockIsolated` collection) is the natural fit for the `async` closures
/// and is `Sendable` by construction under strict concurrency (PLAN Decisions #2). Scheduled requests
/// are keyed by `id`, so re-scheduling the same id **overwrites** — mirroring iOS
/// `UNUserNotificationCenter.add(_:)` and making the PRD §7.3 "re-test in the same ISO week overwrites"
/// behaviour faithful in tests.
public actor RecordingNotificationCenter {
  private var scheduled: [String: NotificationRequest] = [:]
  private var cancelledIDs: [String] = []

  public init() {}

  public func schedule(_ request: NotificationRequest) {
    scheduled[request.id] = request
  }

  public func cancel(_ ids: [String]) {
    for id in ids {
      scheduled[id] = nil
    }
    cancelledIDs.append(contentsOf: ids)
  }

  /// Currently-scheduled identifiers, sorted for deterministic (order-stable) assertions.
  public func pendingIdentifiers() -> [String] {
    scheduled.keys.sorted()
  }

  /// The scheduled requests, sorted by `id` for deterministic assertions.
  public func scheduledRequests() -> [NotificationRequest] {
    scheduled.keys.sorted().compactMap { scheduled[$0] }
  }

  /// The full append-only history of cancelled identifiers.
  public func cancelledIdentifiers() -> [String] {
    cancelledIDs
  }
}
