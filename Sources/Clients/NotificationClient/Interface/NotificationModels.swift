import Foundation

/// The boundary value types for `NotificationClient` (PLAN Decisions #1). These are pure `Sendable`,
/// `Equatable` transport types — **no `UserNotifications`/`UN*` type is exposed across the interface**
/// (that framework stays inside `NotificationClientLive`, which maps these to `UN*`/Foundation
/// `DateComponents`). Keeping the boundary framework-free lets the interface, its consumers (Phase
/// 10.2 Settings, 10.3 wiring), and the host tests compile without importing `UserNotifications`.

/// One identified local notification to schedule. `id` is the stable identifier used for both
/// scheduling and cancellation — re-scheduling the same `id` overwrites the pending request (iOS
/// `UNUserNotificationCenter.add(_:)` semantics), which is how the strength-test "re-test in the same
/// ISO week overwrites" rule (PRD §7.3) falls out naturally.
public struct NotificationRequest: Sendable, Equatable {
  public let id: String
  public let title: String
  public let body: String
  public let trigger: NotificationTrigger

  // Explicit `public init` — the synthesized memberwise init is `internal` across module boundaries.
  public init(id: String, title: String, body: String, trigger: NotificationTrigger) {
    self.id = id
    self.title = title
    self.body = body
    self.trigger = trigger
  }
}

/// The two cadences the reminders need, modelled **without** exposing `UNNotificationTrigger`:
/// - `.calendar` covers the daily morning check-in (`hour`/`minute`, repeating) and the weekly
///   strength test (`weekday`/`hour`/`minute`, repeating).
/// - `.timeInterval` covers a relative one-shot (e.g. "in N days") prompt.
public enum NotificationTrigger: Sendable, Equatable {
  case calendar(dateComponents: NotificationDateComponents, repeats: Bool)
  case timeInterval(seconds: TimeInterval, repeats: Bool)
}

/// A small framework-free mirror of the `DateComponents` fields the calendar triggers use. `*Live`
/// maps it 1:1 to Foundation's `DateComponents`. `weekday` follows the `DateComponents` convention
/// (1 = Sunday … 7 = Saturday) so the mapping is a straight copy with no off-by-one.
public struct NotificationDateComponents: Sendable, Equatable {
  public var weekday: Int?
  public var hour: Int?
  public var minute: Int?

  public init(weekday: Int? = nil, hour: Int? = nil, minute: Int? = nil) {
    self.weekday = weekday
    self.hour = hour
    self.minute = minute
  }
}

/// The authorization states the UX cares about — a hand-rolled enum, **not** `UNAuthorizationStatus`,
/// so the interface and its consumers never import `UserNotifications`. `*Live` maps the `UN*` status
/// onto these (`.ephemeral` collapses to `.authorized`).
public enum NotificationAuthorizationStatus: Sendable, Equatable {
  case notDetermined
  case denied
  case authorized
  case provisional
}

/// A scheduling failure surfaced as a **catchable** Swift error — thrown by **both** the live client
/// and the recording test value so host tests and on-device behaviour agree (review #2.1). The live
/// `UNTimeIntervalNotificationTrigger` otherwise raises an *uncatchable* Obj-C `NSException` for an
/// out-of-range interval; validating up-front in framework-free code (below) turns that into a
/// recoverable `throws`.
public enum NotificationSchedulingError: Error, Equatable, Sendable {
  case invalidTimeInterval(seconds: TimeInterval, repeats: Bool)
  case invalidCalendarComponents(NotificationDateComponents)
}

public extension NotificationTrigger {
  /// Throws `NotificationSchedulingError` if this trigger cannot be scheduled — as pure arithmetic
  /// with **no `UserNotifications` dependency**, so it runs on the host. Both `NotificationClientLive`
  /// and the recording test value validate through this, so a TestStore can't record a schedule that
  /// production would reject. Mirrors the runtime constraints the `UN*` triggers enforce:
  /// - `.timeInterval`: a finite, positive interval, and ≥ 60s when repeating.
  /// - `.calendar`: each present component in range (weekday 1...7, hour 0...23, minute 0...59) and at
  ///   least one component set — an all-nil `DateComponents` raises an uncatchable `NSException` from
  ///   `UNCalendarNotificationTrigger` (Apple requires ≥ 1 component), and out-of-range values produce
  ///   a trigger that never fires.
  func validate() throws {
    switch self {
    case let .timeInterval(seconds, repeats):
      guard seconds.isFinite, seconds > 0, !(repeats && seconds < 60) else {
        throw NotificationSchedulingError.invalidTimeInterval(seconds: seconds, repeats: repeats)
      }
    case let .calendar(components, _):
      let weekdayOK = components.weekday.map { (1 ... 7).contains($0) } ?? true
      let hourOK = components.hour.map { (0 ... 23).contains($0) } ?? true
      let minuteOK = components.minute.map { (0 ... 59).contains($0) } ?? true
      let hasAnyComponent = components.weekday != nil || components.hour != nil || components.minute != nil
      guard weekdayOK, hourOK, minuteOK, hasAnyComponent else {
        throw NotificationSchedulingError.invalidCalendarComponents(components)
      }
    }
  }
}
