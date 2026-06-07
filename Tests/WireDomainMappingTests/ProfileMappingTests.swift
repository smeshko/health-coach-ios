import DomainModels
@testable import WireDomainMapping
import WireModels
import XCTest

final class ProfileMappingTests: XCTestCase {
  func test_profile_carriesEveryField() {
    let profile = domainProfile(WireFixtures.profile())

    XCTAssertEqual(profile.athlete.age, 34)
    XCTAssertEqual(profile.athlete.sex, "male")
    XCTAssertEqual(profile.athlete.heightCm, 182)
    XCTAssertEqual(profile.athlete.goalWeightKg, 75.0)

    XCTAssertEqual(profile.zones.z1, ZoneRange(low: 100, high: 130))
    XCTAssertEqual(profile.zones.z5, ZoneRange(low: 176, high: 190))

    XCTAssertEqual(profile.thresholds.maxHr, 190)
    XCTAssertEqual(profile.thresholds.cadenceTargetSpm, 180)

    XCTAssertEqual(profile.meta.constitutionVersion, "v3")
    XCTAssertEqual(profile.meta.constantsRecomputedWeek, "2026-W22")
  }

  func test_profile_nilConstantsRecomputedWeek_mapsToNil() {
    let profile = domainProfile(WireFixtures.profile(constantsRecomputedWeek: nil))
    XCTAssertNil(profile.meta.constantsRecomputedWeek)
  }
}
