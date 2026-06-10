// Shell snapshot tests (ARCHITECTURE D16): the two top-level `AppView` shell states — the onboarding
// branch (neutral + token-invalid) and the main tab bar — in light + dark on the single reference
// device. The whole body is `#if canImport(UIKit)`-guarded so this target compiles to an empty module
// on the macOS host (so `swift test` stays green); it runs on the iOS 26 simulator via
// `make test-snapshots`. Per-feature state matrices belong to the tab features (Epics 8/9/10).

#if canImport(UIKit)
  import AppFeature
  import CoachTestSupport
  import ComposableArchitecture
  import OnboardingFeature
  import SnapshotTesting
  import Testing

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
      // A stored token is the happy path: pin `tokenClient.read` so the launch check keeps `.main`
      // (otherwise the sim's empty Keychain would fall back to onboarding mid-capture).
      let view = withDependencies {
        $0.tokenClient.read = { "snapshot-token" }
      } operation: {
        AppView(
          store: Store(initialState: .main(MainTabs.State())) {
            AppFeature()
          }
        )
      }
      assertCoachSnapshot(of: view)
    }
  }
#endif
