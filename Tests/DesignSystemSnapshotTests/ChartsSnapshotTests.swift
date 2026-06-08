// Vertical bar chart catalog snapshots — the BarColumns primitive and the TrendChart composite, each on
// its own device-fitting fixture, in light + dark.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import XCTest

  @testable import DesignSystem

  @MainActor
  final class ChartsSnapshotTests: XCTestCase {
    func test_barColumnsCatalog() {
      assertCoachSnapshot(of: BarColumnsCatalogView())
    }

    func test_trendChartCatalog() {
      assertCoachSnapshot(of: ChartsCatalogView())
    }
  }
#endif
