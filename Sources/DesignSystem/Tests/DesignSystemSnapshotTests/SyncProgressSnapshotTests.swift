// SyncProgressView composite gallery-page sections — the `.syncing` and `.generating` full-screen
// states, light + dark on the reference device (mirrors `2 ·`/`3 · Loading` mockups). The matrix now
// lives in the gallery (`SyncProgressPage`); the old catalog has been deleted (D2).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct SyncProgressSnapshotTests {
    @Test func test_syncing() {
      assertCoachSnapshot(of: SyncProgressSection(state: .syncing))
    }

    @Test func test_generating() {
      assertCoachSnapshot(of: SyncProgressSection(state: .generating))
    }

    /// The determinate trim mode (the gallery / future-real-progress demo) — `progress` non-nil.
    @Test func test_determinate() {
      assertCoachSnapshot(of: SyncProgressSection(state: .determinate))
    }

    /// The blocking-sync screen with the quiet Cancel affordance (Phase 12.1, D4).
    @Test func test_cancellable() {
      assertCoachSnapshot(of: SyncProgressSection(state: .cancellable))
    }
  }
#endif
