// SessionCard catalog snapshots — the workout/strength/rest-day variants on the single reference device
// in light + dark. (TASK-005 lands the workout variants; TASK-006 extends the catalog with rest + strength.)

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct SessionCardSnapshotTests {
    @Test func test_sessionCardCatalog() {
      assertCoachSnapshot(of: SessionCardCatalogView())
    }
  }
#endif
