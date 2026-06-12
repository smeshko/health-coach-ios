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

  @Test func test_closedEnum_identityPassThrough() {
    // The closed enums are now shared wire↔domain (Phase 11.3); the helpers are identity
    // pass-throughs that simply return their input.
    #expect(EnumMapping.card(.easyRun) == .easyRun)
    #expect(EnumMapping.card(.rest) == .rest)
    #expect(EnumMapping.zone(.z3) == .z3)
    #expect(EnumMapping.band(.amber) == .amber)
    #expect(EnumMapping.dayType(.hard) == .hard)
    #expect(EnumMapping.intensity(.quality) == .quality)
    #expect(EnumMapping.narrativeType(.caution) == .caution)
    #expect(EnumMapping.tier(.extra) == .extra)
    #expect(EnumMapping.weekday(.sun) == .sun)
  }

  @Test func test_closedEnum_everyCaseMaps() {
    // Totality: the identity pass-through is non-nil for every shared card case.
    for card in Card.allCases {
      #expect(EnumMapping.card(card) == card, "unmapped card: \(card)")
    }
  }
}
