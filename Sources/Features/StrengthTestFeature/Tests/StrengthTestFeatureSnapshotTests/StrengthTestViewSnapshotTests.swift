// StrengthTestView snapshot — the strength-test input screen in its due (callout shown), not-due, and
// load-failed states, light + dark on the single reference device (`Strength Input Screen.png`).
// `#if canImport(UIKit)`-guarded so it compiles to an empty module on the macOS host (SwiftUI image
// snapshots are UIKit-only). Runs on the iOS 26 simulator via `make test-snapshots`.
//
// State is pre-seeded directly. The view's `.onAppear` only auto-loads from `.loading`, so a pre-seeded
// `.loaded`/`.failed` is stable — the appear hook is a no-op and the captured image is deterministic.
// (The transient `.loading` spinner isn't snapshotted — an animating ProgressView isn't pixel-stable.)

#if canImport(UIKit)
  import CoachCore
  import CoachTestSupport
  import ComposableArchitecture
  import Foundation
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import StrengthTestFeature

  @MainActor
  struct StrengthTestViewSnapshotTests {
    private func store(_ state: StrengthTestFeature.State) -> StoreOf<StrengthTestFeature> {
      Store(initialState: state) { StrengthTestFeature() }
    }

    @Test func test_due() {
      // Loaded, last test in a prior ISO week → due, callout shown, 42/11 seeded.
      assertCoachSnapshot(of: StrengthTestView(
        store: store(.init(loadState: .loaded, maxPushups: 42, maxPullups: 11, isDue: true))
      ))
    }

    @Test func test_notDue() {
      // Loaded, a test already logged this ISO week → not due, no callout, 30/8 seeded.
      assertCoachSnapshot(of: StrengthTestView(
        store: store(.init(loadState: .loaded, maxPushups: 30, maxPullups: 8, isDue: false))
      ))
    }

    @Test func test_failed() {
      // The initial `current` read threw → the retry-able failed state (review #1).
      assertCoachSnapshot(of: StrengthTestView(store: store(.init(loadState: .failed))))
    }
  }
#endif
