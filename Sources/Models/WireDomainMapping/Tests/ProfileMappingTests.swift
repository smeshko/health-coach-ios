import DomainModels
import Testing
import WireModels

@testable import WireDomainMapping

struct ProfileMappingTests {
  @Test func test_profile_carriesEveryField() {
    let profile = domainProfile(WireFixtures.profile())

    #expect(profile.athlete.age == 34)
    #expect(profile.athlete.sex == "male")
    #expect(profile.athlete.heightCm == 182)
    #expect(profile.athlete.goalWeightKg == 75.0)

    #expect(profile.zones.z1 == ZoneRange(low: 100, high: 130))
    #expect(profile.zones.z5 == ZoneRange(low: 176, high: 190))

    #expect(profile.thresholds.maxHr == 190)
    #expect(profile.thresholds.cadenceTargetSpm == 180)

    #expect(profile.meta.constitutionVersion == "v3")
    #expect(profile.meta.constantsRecomputedWeek == "2026-W22")
  }

  @Test func test_profile_nilConstantsRecomputedWeek_mapsToNil() {
    let profile = domainProfile(WireFixtures.profile(constantsRecomputedWeek: nil))
    #expect(profile.meta.constantsRecomputedWeek == nil)
  }
}
