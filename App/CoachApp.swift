import APIClientLive
import AppFeature
import BriefRepositoryLive
import CoachCore
import ComposableArchitecture
import Database
import DevSettings
import HealthKitClientLive
import LocalRepositories
import LogClient
import LogClientLive
import NotificationClient
import NotificationClientLive
import ProfileRepositoryLive
import SwiftUI
import SyncRepositoryLive
import TokenClient

/// The composition root (ARCHITECTURE §7.1 / D25 / D3) — the **only** place `*Live` targets are
/// imported. Everything below the app target depends on interfaces; the live values are installed here.
@main
struct CoachApp: App {
  /// The `AppDelegate` owns the single `AppFeature` `Store` (so the notification-tap delegate can reach
  /// it, Phase 10.4); `body` reads it back here. See `AppDelegate` for why its store initializer running
  /// before this `init()`'s `prepareDependencies` is harmless.
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  init() {
    // DEBUG first-launch default: seed mock=true when nothing is persisted yet; no-op in RELEASE. Must
    // run BEFORE dependencies resolve `devSettings`, so the routed repos below read the seeded flag. The
    // dev-menu toggle is the only mock/live control thereafter.
    DevSettings.seedFirstLaunchDefault()

    prepareDependencies {
      $0.context = .live
      // Pin calendar + timeZone to the coaching server's frame (Europe/Sofia) via the canonical helper.
      $0.useEuropeSofia()

      // App-wide logging: console + rotating file, with verbose categories gated by the persisted
      // DevSettings toggles (.http always on). The switch UI lands in Phase 7.4.
      $0.log = .liveValue

      // Local-notification data source for the morning check-in / weekly strength-test reminders
      // (Epic 10.3 wires the actual scheduling). Basic local notifications need no entitlement, only
      // runtime authorization. NotificationClientLive is the only place this framework is touched.
      $0.notificationClient = .liveValue

      // Repos with a remote fork install via `routed(dev)` so the DEBUG `-useMockData` toggle works at
      // runtime; CheckIn/StrengthTest are local-only (no `DevEndpoint`) → installed `.live`. The
      // data-source live values (APIClient/Database/HealthKitClient/TokenClient/DevSettings) auto-resolve
      // under `.live` because their `*Live` products are linked by the app target.
      let dev = $0.devSettings
      $0.briefRepository = .routed(dev)
      $0.syncRepository = .routed(dev)
      $0.profileRepository = .routed(dev)
      $0.checkInRepository = .live
      $0.strengthTestRepository = .live
    }
  }

  var body: some Scene {
    WindowGroup {
      // The single store, owned by the AppDelegate — not constructed inline (so the notification delegate
      // and the view share one store). Launch/restore is unchanged: AppView's `.task` still fires
      // `_restoreSession`/`_appWillAppear` once each.
      AppView(store: appDelegate.store)
    }
  }
}
