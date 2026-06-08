import APIClientLive
import AppFeature
import BriefRepositoryLive
import CheckInRepositoryLive
import CoachCore
import ComposableArchitecture
import DatabaseLive
import DevSettings
import DevSettingsLive
import HealthKitClientLive
import ProfileRepositoryLive
import StrengthTestRepositoryLive
import SwiftUI
import SyncRepositoryLive
import TokenClientLive

/// The composition root (ARCHITECTURE §7.1 / D25 / D3) — the **only** place `*Live` targets are
/// imported. Everything below the app target depends on interfaces; the live values are installed here.
@main
struct CoachApp: App {
  init() {
    // DEBUG dev overrides (launch-arg > env > persisted > default); no-op in RELEASE. Must run BEFORE
    // dependencies resolve `devSettings`, so the routed repos below read the resolved flag.
    DevSettings.applyLaunchOverrides()

    prepareDependencies {
      $0.context = .live
      // Pin calendar + timeZone to the coaching server's frame (Europe/Sofia) via the canonical helper.
      $0.useEuropeSofia()

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
      AppView(store: Store(initialState: AppFeature.State()) { AppFeature() })
    }
  }
}
