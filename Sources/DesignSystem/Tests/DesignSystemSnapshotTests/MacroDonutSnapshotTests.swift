// MacroDonut gallery-page section — the segmented ring in a 3-macro split (with center), an even
// split, and a single fill, light + dark on the reference device. The single source for the matrix
// (the old macro-donut catalog has been deleted).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct MacroDonutSnapshotTests {
    @Test func test_macroDonut() {
      assertCoachSnapshot(of: MacroDonutSection())
    }
  }
#endif
