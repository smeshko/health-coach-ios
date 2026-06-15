// WeeklyTargetsStrip gallery-page sections — light + dark on the reference device. A full strip and a
// nil-`totalRunKm` strip (km cell omitted). Inline `DomainModels.WeeklyTargets` literals (this target has
// no `SampleData` dep).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct WeeklyTargetsStripSnapshotTests {
    @Test func test_weeklyTargetsStripFull() {
      assertCoachSnapshot(of: WeeklyTargetsStripFullSection())
    }

    @Test func test_weeklyTargetsStripNoRun() {
      assertCoachSnapshot(of: WeeklyTargetsStripNoRunSection())
    }
  }
#endif
