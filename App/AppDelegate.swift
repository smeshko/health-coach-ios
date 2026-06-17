import AppFeature
import ComposableArchitecture
import UIKit
import UserNotifications

/// Owns the single `AppFeature` `Store` so the notification-tap delegate can reach it (Phase 10.4).
/// `CoachApp` reads this store back through `@UIApplicationDelegateAdaptor` — one store, no
/// construction-order hazard (the delegate already holds it when a tap arrives).
///
/// **Ordering (not a defect):** the adaptor instantiates this `AppDelegate` — and runs `let store =
/// Store(...)` — *before* `CoachApp.init()`/`prepareDependencies`. That's harmless: constructing a `Store`
/// (and `AppFeature()`/`AppFeature.State()`) reads no `@Dependency`; TCA resolves dependencies lazily at
/// the first reducer run, which happens from `AppView.task` — after `prepareDependencies` has run.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
  let store = Store(initialState: AppFeature.State()) { AppFeature() }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Become the notification delegate so a tapped reminder routes through `didReceive` below.
    UNUserNotificationCenter.current().delegate = self
    return true
  }
}

// The delegate is main-actor-isolated (it owns the `@MainActor` `Store`); isolate the conformance to
// match so `store.send` is a same-actor call rather than a data-race crossing (the system delivers these
// callbacks on the main thread).
extension AppDelegate: @MainActor UNUserNotificationCenterDelegate {
  /// A tapped notification → forward its request identifier into the deep-link mapping (TASK-006). The
  /// weekly strength-test reminder (`reminder.weekly-strength-test`) routes to the You tab + the pushed
  /// `StrengthTestFeature`; the morning check-in reminder maps to nothing (fire-and-open).
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    store.send(.notificationOpened(identifier: response.notification.request.identifier))
    completionHandler()
  }
}
