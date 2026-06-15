// CarbCyclingPattern gallery-page sections — light + dark on the reference device. A with-rest-day chart
// (carbs visibly up on hard days, down on the rest-day cut) and a no-rest-day chart (empty gap slots).
// Inline `DomainModels` literals (this target has no `SampleData` dep).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct CarbCyclingPatternSnapshotTests {
    @Test func test_carbCyclingWithRest() {
      assertCoachSnapshot(of: CarbCyclingPatternWithRestSection())
    }

    @Test func test_carbCyclingNoRest() {
      assertCoachSnapshot(of: CarbCyclingPatternNoRestSection())
    }
  }
#endif
