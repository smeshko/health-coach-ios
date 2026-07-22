import DomainModels
import Testing

@testable import DesignSystem

/// Pins the readiness meter's marker placement now that the active band is the backend-computed
/// domain `ReadinessBand` (Phase 20.1, DECISIONS D3): the marker sits in the passed band's segment,
/// and its in-segment fraction is clamped to 0…1 so an inconsistent (score, band) payload pins the
/// marker at the band edge instead of escaping the segment.
struct SegmentedBarTests {
  /// Meter order is red → amber → green (left to right).
  private let amberIndex = 1

  @Test func test_readiness_consistentPair_keepsInSegmentFraction() throws {
    let bar = SegmentedBar.readiness(score: 60, band: .amber)
    let marker = try #require(bar.marker)
    #expect(marker.segmentIndex == amberIndex)
    // Amber axis range is 50…75, so 60 sits at (60-50)/25 = 0.4.
    #expect(abs(marker.fraction - 0.4) < 0.0001)
  }

  @Test func test_readiness_inconsistentPair_clampsMarkerToBandEdge() throws {
    // score 80 in the amber band's 50…75 axis would be 1.2 unclamped — the D3 clamp pins it at 1.0,
    // and the highlight stays in the trusted band's segment.
    let bar = SegmentedBar.readiness(score: 80, band: .amber)
    let marker = try #require(bar.marker)
    #expect(marker.segmentIndex == amberIndex)
    #expect(marker.fraction == 1.0)
  }

  @Test func test_readiness_lowInconsistentPair_clampsMarkerToLowerEdge() throws {
    let bar = SegmentedBar.readiness(score: 10, band: .amber)
    let marker = try #require(bar.marker)
    #expect(marker.segmentIndex == amberIndex)
    #expect(marker.fraction == 0.0)
  }

  @Test func test_readiness_bandSegmentsFollowMeterOrder() throws {
    for (band, index) in [(ReadinessBand.red, 0), (.amber, 1), (.green, 2)] {
      let bar = SegmentedBar.readiness(score: 60, band: band)
      let marker = try #require(bar.marker)
      #expect(marker.segmentIndex == index)
    }
  }
}
