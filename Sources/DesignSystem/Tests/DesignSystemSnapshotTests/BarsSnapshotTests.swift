// Bar composites + prehab row catalog snapshot (Phase 5.2 TASK-002) — light + dark.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct BarsSnapshotTests {
    @Test func test_barsCatalog() {
      assertCoachSnapshot(of: BarsCatalogView())
    }
  }
#endif
