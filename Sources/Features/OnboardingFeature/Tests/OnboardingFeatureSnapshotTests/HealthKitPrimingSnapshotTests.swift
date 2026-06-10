// HealthKit priming + degraded snapshots (ARCHITECTURE D16): the two designed states — the **priming**
// explainer and the **degraded-permissions** screen — in light + dark on the single reference device,
// via the shared `CoachTestSupport` harness (`assertCoachSnapshot(of:)`). The whole body is
// `#if canImport(UIKit)`-guarded so this target compiles to an empty module on the macOS host (so
// `swift test` stays green); it runs on the iOS 26 simulator via `make test-snapshots`.
//
// Re-record workflow (references are environment-sensitive, D16): set `assertCoachSnapshot`'s `record:`
// default to `.all` in `SnapshotConvention.swift` (the env-var record mode does not reach the simulator
// test runner), run on the pinned iPhone 17 Pro / iOS 26 simulator, then revert and commit the PNGs.
//
// `@testable import` reaches the internal `HealthKitPrimingView` / `DegradedPermissionsView` + the
// `HealthKitPriming.State` initializer without widening their visibility (mirrors 5.1's catalog test).

#if canImport(UIKit)
  import CoachTestSupport
  import ComposableArchitecture
  import SnapshotTesting
  import Testing

  @testable import OnboardingFeature

  @MainActor
  struct HealthKitPrimingSnapshotTests {
    @Test func test_healthKitPriming_idleState() {
      let view = HealthKitPrimingView(
        store: Store(initialState: HealthKitPriming.State()) {
          HealthKitPriming()
        }
      )
      assertCoachSnapshot(of: view)
    }

    @Test func test_degradedPermissions_partialState() {
      let summary = HealthKitPriming.DegradedSummary(missing: [.sleep, .vo2Max])
      let view = DegradedPermissionsView(
        store: Store(initialState: HealthKitPriming.State(phase: .degraded(summary))) {
          HealthKitPriming()
        },
        summary: summary
      )
      assertCoachSnapshot(of: view)
    }
  }
#endif
