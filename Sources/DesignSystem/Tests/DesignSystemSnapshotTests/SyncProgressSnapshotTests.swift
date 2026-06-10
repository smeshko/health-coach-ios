// SyncProgressView composite catalog snapshots — the `.syncing` and `.generating` states, light + dark
// on the reference device. Mirrors `2 ·`/`3 · Loading` mockups.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct SyncProgressSnapshotTests {
    @Test func test_syncing() {
      assertCoachSnapshot(of: SyncProgressCatalogView(state: .syncing))
    }

    @Test func test_generating() {
      assertCoachSnapshot(of: SyncProgressCatalogView(state: .generating))
    }
  }
#endif
