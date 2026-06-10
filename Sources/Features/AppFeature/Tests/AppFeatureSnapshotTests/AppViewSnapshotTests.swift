// Shell snapshot tests (ARCHITECTURE D16): the two top-level `AppView` shell states — the onboarding
// branch (neutral + token-invalid) and the main tab bar — in light + dark on the single reference
// device. The whole body is `#if canImport(UIKit)`-guarded so this target compiles to an empty module
// on the macOS host (so `swift test` stays green); it runs on the iOS 26 simulator via
// `make test-snapshots`. Per-feature state matrices belong to the tab features (Epics 8/9/10).

#if canImport(UIKit)
  import AppFeature
  import CoachCore
  import CoachTestSupport
  import ComposableArchitecture
  import Foundation
  import OnboardingFeature
  import SnapshotTesting
  import SyncRepository
  import Testing
  import TodayFeature

  @MainActor
  struct AppViewSnapshotTests {
    @Test func test_onboardingShell_neutral() {
      let view = AppView(
        store: Store(initialState: .onboarding(OnboardingFeature.State(step: .connect(reason: nil)))) {
          AppFeature()
        }
      )
      assertCoachSnapshot(of: view)
    }

    @Test func test_onboardingShell_tokenInvalid() {
      let view = AppView(
        store: Store(
          initialState: .onboarding(OnboardingFeature.State(step: .connect(reason: .tokenInvalid)))
        ) {
          AppFeature()
        }
      )
      assertCoachSnapshot(of: view)
    }

    @Test func test_mainTabBar() {
      // The Today tab is the default selection and now renders the real `TodayView`. The shell fires
      // `onAppOpen` when the tab bar appears, so make the capture deterministic instead of racing the
      // async sync→brief chain: seed the Today root to `.syncing` AND park the app-open `sync()` so it
      // never advances past `.syncing` (the store is torn down at test end, cancelling the parked task).
      // `tokenClient.read` returns a token so the launch check keeps `.main` (the sim's empty Keychain
      // would otherwise fall back to onboarding mid-capture). The whole capture runs inside
      // `withDependencies` so the Today header's `@Dependency(\.date)`/`(\.calendar)` (read at *render*
      // time) resolve to the pinned Europe/Sofia instant — otherwise the date subtitle would track the
      // real clock and the reference would rot.
      var components = DateComponents()
      components.year = 2026
      components.month = 6
      components.day = 5
      components.hour = 9
      let fixedInstant = Calendar.europeSofia.date(from: components)!

      var mainState = MainTabs.State()
      mainState.todayRoot = TodayFeature.State(briefState: .syncing)

      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant)
        $0.tokenClient.read = { "snapshot-token" }
        $0.syncRepository.sync = {
          try await Task.sleep(for: .seconds(3600))
          throw CancellationError() // unreachable; keeps Today parked on `.syncing` for the capture
        }
      } operation: {
        let view = AppView(store: Store(initialState: .main(mainState)) { AppFeature() })
        assertCoachSnapshot(of: view)
      }
    }
  }
#endif
