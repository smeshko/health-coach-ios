// NumericStepper gallery-page section — the large-numeral counter across min/mid/max values, light +
// dark on the reference device (the counter in `Strength Input Screen.png`). The matrix lives in the
// gallery (`NumericStepperPage`); the snapshot asserts the device-fitting section directly.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct NumericStepperSnapshotTests {
    @Test func test_numericStepper() {
      assertCoachSnapshot(of: NumericStepperSection())
    }
  }
#endif
