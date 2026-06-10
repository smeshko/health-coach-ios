// Check-in input controls catalog snapshots — `YesNoToggle` + `DotStepper`/severity badge, light + dark
// on the reference device. Mirrors the inputs in `1 · Daily Check-in.png`.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct CheckInControlsSnapshotTests {
    @Test func test_checkInControls() {
      assertCoachSnapshot(of: CheckInControlsCatalogView())
    }
  }
#endif
