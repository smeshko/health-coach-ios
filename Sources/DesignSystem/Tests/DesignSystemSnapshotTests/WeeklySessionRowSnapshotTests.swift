// WeeklySessionRow gallery-page sections — light + dark on the reference device. Two device-fitting
// sections (core cardio + strength; extras / nil-day / nil-durations) so the badge variants (HARD/EASY),
// the day-chip core-solid vs extra-outline treatment, the mini zone bar, and the derived effort scale are
// all locked. Inline `DomainModels` literals (this target has no `SampleData` dep).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct WeeklySessionRowSnapshotTests {
    @Test func test_weeklySessionRowCore() {
      assertCoachSnapshot(of: WeeklySessionRowCoreSection())
    }

    @Test func test_weeklySessionRowExtras() {
      assertCoachSnapshot(of: WeeklySessionRowExtrasSection())
    }
  }
#endif
