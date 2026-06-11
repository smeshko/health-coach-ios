import DomainModels
import Testing

@testable import DesignSystem

struct EffortBandTests {
  /// Each zone maps to its RPE band per the user's zone→RPE table.
  @Test func test_effortBand_mapsEachZone() {
    func band(_ zone: Zone) -> ClosedRange<Int> {
      effortBand(for: SessionBlock(
        card: .easyRun, intensity: .easy, zoneTarget: zone, durationMinLow: 30, durationMinHigh: 30
      ))
    }
    #expect(band(.z1) == 1 ... 3)
    #expect(band(.z2) == 3 ... 4)
    #expect(band(.z3) == 5 ... 6)
    #expect(band(.z4) == 7 ... 8)
    #expect(band(.z5) == 9 ... 10)
  }

  /// With no `zoneTarget`, the band falls back to intensity — quality high, recovery low, easy in between.
  @Test func test_effortBand_fallsBackToIntensity_whenNoZone() {
    func band(_ intensity: Intensity) -> ClosedRange<Int> {
      effortBand(for: SessionBlock(
        card: .strengthLower, intensity: intensity, durationMinLow: 45, durationMinHigh: 45
      ))
    }
    #expect(band(.quality) == 7 ... 8)
    #expect(band(.recovery) == 2 ... 3)
    #expect(band(.easy) == 3 ... 4)
  }
}
