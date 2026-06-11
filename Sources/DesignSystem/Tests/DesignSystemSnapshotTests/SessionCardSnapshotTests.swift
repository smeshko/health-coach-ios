// SessionCard catalog snapshots — light + dark on the single reference device. The cardio pair fits one
// device frame; the taller strength + rest variants each get their own fixture so nothing clips below the
// fold.

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

    @Test func test_sessionCardStrength() {
      assertCoachSnapshot(of: SessionCardStrengthCatalogView())
    }

    @Test func test_sessionCardRest() {
      assertCoachSnapshot(of: SessionCardRestCatalogView())
    }
  }
#endif
