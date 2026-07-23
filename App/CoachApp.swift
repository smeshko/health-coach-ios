import APIClient
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
    // DEBUG first-launch default: seed live iff a backend is actually configured (CR-1 coherence —
    // an unconfigured fresh install seeds mock instead of a guaranteed-failing live run); no-op in
    // RELEASE. Must run BEFORE dependencies resolve `devSettings`, so the routed repos below read the
    // seeded flag. The dev-menu toggle is the only mock/live control thereafter.
    DevSettings.seedFirstLaunchDefault(liveBackendConfigured: AppConfig.apiBaseURL != nil)

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

      // APIClient is injected EXPLICITLY (CR-1): the composition root owns the base URL end-to-end
      // (API_BASE_URL build setting → Info.plist → AppConfig → here). Unconfigured installs get the
      // throwing `.unconfigured` client — loud at first use, never a silent localhost target.
      if let baseURL = AppConfig.apiBaseURL {
        $0.apiClient = .live(baseURL: baseURL, extraHeaders: AppConfig.cfAccessHeaders)
      } else {
        $0.apiClient = .unconfigured
        // `.http`, not `.app`: the misconfiguration diagnostic must ride the ALWAYS-ON network
        // category (`.app` is gated off by default, off unconditionally in RELEASE — review
        // round-2 #1a), and a missing base URL is transport observability anyway.
        $0.log.error(
          "API base URL unconfigured — set API_BASE_URL; APIClient will throw on use",
          category: .http
        )
      }

      // Repos with a remote fork install via `routed(dev)` so the DEBUG `-useMockData` toggle works at
      // runtime; CheckIn/StrengthTest are local-only (no `DevEndpoint`) → installed `.live`. The
      // remaining data-source live values (Database/HealthKitClient/TokenClient/DevSettings)
      // auto-resolve under `.live` because their `*Live` products are linked by the app target —
      // APIClient no longer auto-resolves; it is injected explicitly above.
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
