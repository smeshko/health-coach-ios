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

  // NOTE: the closed enums are now shared wire↔domain (Phase 11.3) — no `EnumMapping` helper exists
  // for them, so there are no closed-enum mapping assertions here. Their strictness lives at the
  // `WireModels` decode boundary (DecodeRoundTripTests).
}
