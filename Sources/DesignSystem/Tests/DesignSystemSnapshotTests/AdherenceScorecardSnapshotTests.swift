// AdherenceScorecard gallery-page sections — light + dark on the reference device. The present scorecard
// (all fields), a present scorecard with some nil fields ("—"), and the empty "not enough data last week"
// state. Inline `DomainModels` literals (this target has no `SampleData` dep).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct AdherenceScorecardSnapshotTests {
    @Test func test_adherencePresent() {
      assertCoachSnapshot(of: AdherenceScorecardPresentSection())
    }

    @Test func test_adherencePartialNil() {
      assertCoachSnapshot(of: AdherenceScorecardPartialSection())
    }

    @Test func test_adherenceEmpty() {
      assertCoachSnapshot(of: AdherenceScorecardEmptySection())
    }
  }
#endif
