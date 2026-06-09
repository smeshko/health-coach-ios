import DomainModels
import Testing
import WireModels

@testable import WireDomainMapping

struct EnumMappingTests {
  @Test func test_freeStringFlags_mapKnownCases() {
    #expect(EnumMapping.flag("impact") == .impact)
    #expect(EnumMapping.flag("needs_green_knee") == .needsGreenKnee)
    #expect(EnumMapping.flag("prefer_low_impact") == .preferLowImpact)
    #expect(EnumMapping.flag("prehab:foot") == .prehabFoot)
    #expect(EnumMapping.flag("prehab:glute") == .prehabGlute)
    #expect(EnumMapping.flag("quality_day") == .qualityDay)
  }

  @Test func test_freeStringFlag_unknownSurvivesVerbatim() {
    #expect(EnumMapping.flag("totally_new_flag") == .unknown("totally_new_flag"))
  }

  @Test func test_freeStringReasonsAndFactors_mapKnownAndUnknown() {
    #expect(EnumMapping.safetyReason("gi_flare") == .giFlare)
    #expect(EnumMapping.safetyReason("knee_pain_high") == .kneePainHigh)
    #expect(EnumMapping.safetyReason("brand_new") == .unknown("brand_new"))

    #expect(EnumMapping.penaltyFactor("hrv_below_baseline") == .hrvBelowBaseline)
    #expect(EnumMapping.penaltyFactor("yesterday_hard_day") == .yesterdayHardDay)
    #expect(EnumMapping.penaltyFactor("brand_new") == .unknown("brand_new"))
  }

  @Test func test_closedEnum_knownCasesRoundTrip() {
    #expect(EnumMapping.card(.known(.easyRun)) == .easyRun)
    #expect(EnumMapping.card(.known(.rest)) == .rest)
    #expect(EnumMapping.zone(.known(.z3)) == .z3)
    #expect(EnumMapping.band(.known(.amber)) == .amber)
    #expect(EnumMapping.dayType(.known(.hard)) == .hard)
    #expect(EnumMapping.intensity(.known(.quality)) == .quality)
    #expect(EnumMapping.narrativeType(.known(.caution)) == .caution)
    #expect(EnumMapping.tier(.known(.extra)) == .extra)
    #expect(EnumMapping.weekday(.known(.sun)) == .sun)
  }

  @Test func test_closedEnum_everyWireCaseMaps() {
    // Totality: every wire case maps to a domain case (no nil for a known value).
    for card in WorkoutCard.allCases {
      #expect(EnumMapping.card(.known(card)) != nil, "unmapped card: \(card)")
    }
  }

  @Test func test_closedEnum_unknownReturnsNil() {
    #expect(EnumMapping.card(.unknown("new_card")) == nil)
    #expect(EnumMapping.zone(.unknown("z9")) == nil)
    #expect(EnumMapping.band(.unknown("teal")) == nil)
  }
}
