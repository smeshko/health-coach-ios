// Atom/control primitives catalog snapshot (Phase 5.2 TASK-001) — light + dark on the reference
// device. `#if canImport(UIKit)`-guarded; the fixture is internal, reached via `@testable import`.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import XCTest

  @testable import DesignSystem

  @MainActor
  final class AtomsSnapshotTests: XCTestCase {
    func test_atomsCatalog() {
      assertCoachSnapshot(of: AtomsCatalogView())
    }
  }
#endif
