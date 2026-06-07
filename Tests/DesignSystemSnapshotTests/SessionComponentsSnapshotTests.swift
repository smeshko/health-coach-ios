// Session vocabulary components catalog snapshot (Phase 5.3 TASK-001) — light + dark.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import XCTest

  @testable import DesignSystem

  @MainActor
  final class SessionComponentsSnapshotTests: XCTestCase {
    func test_sessionComponentsCatalog() {
      assertCoachSnapshot(of: SessionComponentsCatalogView())
    }
  }
#endif
