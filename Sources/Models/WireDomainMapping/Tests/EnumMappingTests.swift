import DomainModels
@testable import WireDomainMapping
import WireModels
import XCTest

final class EnumMappingTests: XCTestCase {
  func test_freeStringFlags_mapKnownCases() {
    XCTAssertEqual(EnumMapping.flag("impact"), .impact)
    XCTAssertEqual(EnumMapping.flag("needs_green_knee"), .needsGreenKnee)
    XCTAssertEqual(EnumMapping.flag("prefer_low_impact"), .preferLowImpact)
    XCTAssertEqual(EnumMapping.flag("prehab:foot"), .prehabFoot)
    XCTAssertEqual(EnumMapping.flag("prehab:glute"), .prehabGlute)
    XCTAssertEqual(EnumMapping.flag("quality_day"), .qualityDay)
  }

  func test_freeStringFlag_unknownSurvivesVerbatim() {
    XCTAssertEqual(EnumMapping.flag("totally_new_flag"), .unknown("totally_new_flag"))
  }

  func test_freeStringReasonsAndFactors_mapKnownAndUnknown() {
    XCTAssertEqual(EnumMapping.safetyReason("gi_flare"), .giFlare)
    XCTAssertEqual(EnumMapping.safetyReason("knee_pain_high"), .kneePainHigh)
    XCTAssertEqual(EnumMapping.safetyReason("brand_new"), .unknown("brand_new"))

    XCTAssertEqual(EnumMapping.penaltyFactor("hrv_below_baseline"), .hrvBelowBaseline)
    XCTAssertEqual(EnumMapping.penaltyFactor("yesterday_hard_day"), .yesterdayHardDay)
    XCTAssertEqual(EnumMapping.penaltyFactor("brand_new"), .unknown("brand_new"))
  }

  func test_closedEnum_knownCasesRoundTrip() {
    XCTAssertEqual(EnumMapping.card(.known(.easyRun)), .easyRun)
    XCTAssertEqual(EnumMapping.card(.known(.rest)), .rest)
    XCTAssertEqual(EnumMapping.zone(.known(.z3)), .z3)
    XCTAssertEqual(EnumMapping.band(.known(.amber)), .amber)
    XCTAssertEqual(EnumMapping.dayType(.known(.hard)), .hard)
    XCTAssertEqual(EnumMapping.intensity(.known(.quality)), .quality)
    XCTAssertEqual(EnumMapping.narrativeType(.known(.caution)), .caution)
    XCTAssertEqual(EnumMapping.tier(.known(.extra)), .extra)
    XCTAssertEqual(EnumMapping.weekday(.known(.sun)), .sun)
  }

  func test_closedEnum_everyWireCaseMaps() {
    // Totality: every wire case maps to a domain case (no nil for a known value).
    for card in WorkoutCard.allCases {
      XCTAssertNotNil(EnumMapping.card(.known(card)), "unmapped card: \(card)")
    }
  }

  func test_closedEnum_unknownReturnsNil() {
    XCTAssertNil(EnumMapping.card(.unknown("new_card")))
    XCTAssertNil(EnumMapping.zone(.unknown("z9")))
    XCTAssertNil(EnumMapping.band(.unknown("teal")))
  }
}
