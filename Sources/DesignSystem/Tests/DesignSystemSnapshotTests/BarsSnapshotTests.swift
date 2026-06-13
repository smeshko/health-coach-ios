// SegmentedBar + BarColumns gallery-page sections — light + dark on the reference device. The
// `SegmentedBar` matrix is split across two device-fitting sections (zones + readiness; effort range +
// weekly streak) so nothing clips below the fold; `BarColumns` fits one section. These sections are
// the single source for each matrix (the old bars + bar-columns catalogs have been
// deleted).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct BarsSnapshotTests {
    @Test func test_segmentedBarZones() {
      assertCoachSnapshot(of: SegmentedBarZonesSection())
    }

    @Test func test_segmentedBarMeter() {
      assertCoachSnapshot(of: SegmentedBarMeterSection())
    }

    @Test func test_barColumns() {
      assertCoachSnapshot(of: BarColumnsSection())
    }
  }
#endif
