// NutritionGauge catalog snapshots — the "TODAY'S FUEL" card (donut + legend + day-type chip) for the
// hard / moderate / rest day types, in light + dark on the single reference device.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct NutritionGaugeSnapshotTests {
    @Test func test_nutritionGaugeCatalog() {
      assertCoachSnapshot(of: NutritionGaugeCatalogView())
    }
  }
#endif
