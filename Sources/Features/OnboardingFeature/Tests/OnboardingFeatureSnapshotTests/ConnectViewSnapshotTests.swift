// ConnectView snapshots (ARCHITECTURE D16): the two designed states — the **connect** state and the
// **connect-error** state — in light + dark on the single reference device, via the shared
// `CoachTestSupport` harness (`assertCoachSnapshot(of:)`, reused — not re-encoded). The whole body is
// `#if canImport(UIKit)`-guarded so this target compiles to an empty module on the macOS host (so
// `swift test` stays green); it runs on the iOS 26 simulator via `make test-snapshots`.
//
// Re-record workflow (references are environment-sensitive, D16): set `assertCoachSnapshot`'s `record:`
// default to `.all` in `SnapshotConvention.swift` (the env-var record mode does not reach the simulator
// test runner), run on the pinned iPhone 17 Pro / iOS 26 simulator, then revert and commit the PNGs.
//
// `@testable import` reaches the internal `ConnectView` + the `ConnectComponent.State` initializer
// without widening their visibility (mirrors 5.1's catalog snapshot test).

#if canImport(UIKit)
  import CoachTestSupport
  import ComposableArchitecture
  import SnapshotTesting
  import XCTest

  @testable import OnboardingFeature

  @MainActor
  final class ConnectViewSnapshotTests: XCTestCase {
    func test_connect_idleState() {
      let view = ConnectView(
        store: Store(initialState: ConnectComponent.State(token: "ahc_live_a8f2c1d9")) {
          ConnectComponent()
        }
      )
      assertCoachSnapshot(of: view)
    }

    func test_connect_errorState() {
      let view = ConnectView(
        store: Store(initialState: ConnectComponent.State(token: "ahc_live_x93k7q", validation: .invalid)) {
          ConnectComponent()
        }
      )
      assertCoachSnapshot(of: view)
    }
  }
#endif
