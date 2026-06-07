// Brief components snapshots (Phase 5.4 TASK-005) — readiness bands, nutrition day types, the five
// narrative types, light + dark.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import XCTest

  @testable import DesignSystem

  @MainActor
  final class BriefComponentsSnapshotTests: XCTestCase {
    func test_readinessGauge_bands() {
      assertCoachSnapshot(of: ReadinessGaugeCatalogView())
    }

    func test_nutritionPanel_dayTypes() {
      assertCoachSnapshot(of: NutritionPanelCatalogView())
    }

    func test_narrativeRenderer_allTypes() {
      assertCoachSnapshot(of: NarrativeRendererCatalogView())
    }
  }
#endif
