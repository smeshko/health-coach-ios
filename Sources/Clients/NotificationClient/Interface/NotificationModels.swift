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
