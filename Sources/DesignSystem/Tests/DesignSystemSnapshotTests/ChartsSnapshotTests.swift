// TrendChart composite gallery-page section — the three reference shapes (flat / ramp / recolored) on
// surface cards, light + dark on the reference device. This section is the single source for the
// matrix (the old charts catalog has been deleted; `BarColumns` now lives in `BarsSnapshotTests`).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct ChartsSnapshotTests {
    @Test func test_trendChart() {
      assertCoachSnapshot(of: ChartSection())
    }
  }
#endif
