// SessionCard representative-card snapshots (Phase 5.3 TASK-004) — light + dark. Split so every card
// is fully captured within the device height.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import XCTest

  @testable import DesignSystem

  @MainActor
  final class SessionCardSnapshotTests: XCTestCase {
    func test_sessionCard_runs() {
      assertCoachSnapshot(of: SessionCardRunsCatalogView())
    }

    func test_sessionCard_variants() {
      assertCoachSnapshot(of: SessionCardVariantsCatalogView())
    }
  }
#endif
