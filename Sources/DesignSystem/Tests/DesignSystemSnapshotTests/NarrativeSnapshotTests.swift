// NarrativeRenderer gallery-page section — the verbatim eyebrow sections + the soft "gentle note"
// caution callout, light + dark on the reference device. The single source for the matrix (the
// old narrative catalog has been deleted).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct NarrativeSnapshotTests {
    @Test func test_narrative() {
      assertCoachSnapshot(of: NarrativeGallerySection())
    }
  }
#endif
