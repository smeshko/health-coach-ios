// MacroDonut catalog snapshots — the segmented ring in a 3-macro split (with center), an even split, and
// a single fill, in light + dark on the single reference device.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct MacroDonutSnapshotTests {
    @Test func test_macroDonutCatalog() {
      assertCoachSnapshot(of: MacroDonutCatalogView())
    }
  }
#endif
