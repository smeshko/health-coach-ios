// Vertical bar chart catalog snapshots — the BarColumns primitive and the TrendChart composite, each on
// its own device-fitting fixture, in light + dark.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystem

  @MainActor
  struct ChartsSnapshotTests {
    @Test func test_barColumnsCatalog() {
      assertCoachSnapshot(of: BarColumnsCatalogView())
    }

    @Test func test_trendChartCatalog() {
      assertCoachSnapshot(of: ChartsCatalogView())
    }
  }
#endif
