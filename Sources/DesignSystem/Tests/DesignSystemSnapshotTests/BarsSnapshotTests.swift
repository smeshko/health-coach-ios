// Bar composites + prehab row catalog snapshot (Phase 5.2 TASK-002) — light + dark.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import XCTest

  @testable import DesignSystem

  @MainActor
  final class BarsSnapshotTests: XCTestCase {
    func test_barsCatalog() {
      assertCoachSnapshot(of: BarsCatalogView())
    }
  }
#endif
