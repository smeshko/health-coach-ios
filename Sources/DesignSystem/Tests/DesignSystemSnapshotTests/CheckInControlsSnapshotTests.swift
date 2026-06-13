// Check-in input controls gallery-page section — `YesNoToggle` + `SegmentStepper`/severity badge,
// light + dark on the reference device (mirrors the inputs in `1 · Daily Check-in.png`). The matrix
// now lives in the gallery (`CheckInControlsPage`); the old catalog has been deleted (D2).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct CheckInControlsSnapshotTests {
    @Test func test_checkInControls() {
      assertCoachSnapshot(of: CheckInControlsSection())
    }
  }
#endif
