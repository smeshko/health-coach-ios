// SessionCard gallery-page sections — light + dark on the reference device. The card variants are
// tall, so each is its own device-fitting section (cardio pair / strength / rest) so nothing clips
// below the fold. These sections are the single source for the matrix (the
// old session-card catalog family has been deleted).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct SessionCardSnapshotTests {
    @Test func test_sessionCardEasyRun() {
      assertCoachSnapshot(of: SessionCardEasyRunSection())
    }

    @Test func test_sessionCardQuality() {
      assertCoachSnapshot(of: SessionCardQualitySection())
    }

    @Test func test_sessionCardStrength() {
      assertCoachSnapshot(of: SessionCardStrengthSection())
    }

    @Test func test_sessionCardRest() {
      assertCoachSnapshot(of: SessionCardRestSection())
    }
  }
#endif
