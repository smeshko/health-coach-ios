// CoachNoteCard gallery-page sections — light + dark on the reference device: the plain `.session`
// paragraph state and the session + `.caution` (forced-rest slice) state.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct CoachNoteCardSnapshotTests {
    @Test func test_coachNoteCardSession() {
      assertCoachSnapshot(of: CoachNoteCardSessionSection())
    }

    @Test func test_coachNoteCardCaution() {
      assertCoachSnapshot(of: CoachNoteCardCautionSection())
    }
  }
#endif
