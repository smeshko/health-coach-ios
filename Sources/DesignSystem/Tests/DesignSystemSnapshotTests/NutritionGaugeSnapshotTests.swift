// NutritionGauge gallery-page section — the "TODAY'S FUEL" card (donut + legend + day-type chip) for
// the hard / moderate / rest day types, light + dark on the reference device. The single source for
// the matrix (the old nutrition-gauge catalog has been deleted).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct NutritionGaugeSnapshotTests {
    @Test func test_nutritionGauge() {
      assertCoachSnapshot(of: NutritionGaugeSection())
    }

    @Test func test_nutritionGaugeRest() {
      assertCoachSnapshot(of: NutritionGaugeRestSection())
    }
  }
#endif
