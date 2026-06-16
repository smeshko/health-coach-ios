import Dependencies
import NotificationClient

#if canImport(UserNotifications)
  import Foundation
  import UserNotifications

  /// The live `NotificationClient` over `UNUserNotificationCenter`. This is the **only** target that
  /// imports `UserNotifications` (§15) — it maps the interface's framework-free value types to/from the
  /// `UN*`/Foundation `DateComponents` types. All framework code sits under
  /// `#if canImport(UserNotifications)` so the macOS host build collapses to the `#else` stub.
  extension NotificationClient: DependencyKey {
    public static let liveValue = NotificationClient(
      requestAuthorization: {
        // Discard the granted `Bool` (`_ =`) — the status is re-read from `notificationSettings()`; a
        // bound-but-unused `granted` would warn and fail the no-warnings build.
        _ = try await UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .sound, .badge])
        return await currentStatus()
      },
      authorizationStatus: { await currentStatus() },
      schedule: { request in
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        let req = UNNotificationRequest(
          identifier: request.id,
          content: content,
          trigger: makeTrigger(request.trigger)
        )
        // Re-adding the same identifier overwrites the pending request (iOS semantics).
        try await UNUserNotificationCenter.current().add(req)
      },
      cancel: { ids in
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
      },
      pendingIdentifiers: {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
      }
    )

    private static func currentStatus() async -> NotificationAuthorizationStatus {
      let settings = await UNUserNotificationCenter.current().notificationSettings()
      switch settings.authorizationStatus {
      case .notDetermined: return .notDetermined
      case .denied: return .denied
      case .authorized: return .authorized
      case .provisional: return .provisional
      case .ephemeral: return .authorized
      @unknown default: return .notDetermined
      }
    }

    private static func makeTrigger(_ trigger: NotificationTrigger) -> UNNotificationTrigger {
      switch trigger {
      case let .calendar(components, repeats):
        var dateComponents = DateComponents()
        dateComponents.weekday = components.weekday
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute
        return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
      case let .timeInterval(seconds, repeats):
        return UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: repeats)
      }
    }
  }

#else

  /// macOS-host / no-`UserNotifications` stub: `liveValue` collapses to a safe no-op so the target
  /// compiles to an effectively-empty module off-device. The real path runs on a simulator/device.
  extension NotificationClient: DependencyKey {
    public static let liveValue = NotificationClient(
      requestAuthorization: { .notDetermined },
      authorizationStatus: { .notDetermined },
      schedule: { _ in },
      cancel: { _ in },
      pendingIdentifiers: { [] }
    )
  }

#endif
