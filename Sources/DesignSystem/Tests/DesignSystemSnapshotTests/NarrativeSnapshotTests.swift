// NarrativeRenderer catalog snapshots — the verbatim eyebrow sections + the soft "gentle note" caution
// callout, in light + dark on the single reference device.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct NarrativeSnapshotTests {
    @Test func test_narrativeCatalog() {
      assertCoachSnapshot(of: NarrativeCatalogView())
    }
  }
#endif
