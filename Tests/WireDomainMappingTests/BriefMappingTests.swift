import DomainModels
@testable import WireDomainMapping
import WireModels
import XCTest

final class BriefMappingTests: XCTestCase {
  func test_dailyBrief_fullyPopulated_carriesEveryField() throws {
    let brief = try domainDailyBrief(WireFixtures.dailyBrief())
    // Full-struct equality enforces totality structurally — every field must match, so a future
    // same-typed field transposition (e.g. fatGLow/fatGHigh) cannot pass silently.
    XCTAssertEqual(brief, DomainFixtures.dailyBrief())
  }

  func test_dailyBrief_nullIntakeYesterday_mapsToNil() throws {
    let brief = try domainDailyBrief(WireFixtures.dailyBrief(intakeYesterday: nil))
    XCTAssertNil(brief.intakeYesterday)
  }

  func test_dailyBrief_emptyAlternatives_mapsToEmpty() throws {
    let brief = try domainDailyBrief(WireFixtures.dailyBrief(alternatives: []))
    XCTAssertEqual(brief.alternatives, [])
  }

  func test_unknownFlag_survivesMapWithRawString() throws {
    // The epic's stated validation — an unknown flag carries its exact raw string through the map.
    let brief = try domainDailyBrief(WireFixtures.dailyBrief())
    XCTAssertTrue(brief.session.flags.contains(.unknown("totally_new_flag")))
  }

  // MARK: - Closed-enum out-of-set, by position (DECISIONS Decision 2)

  func test_outOfSetCard_inCollectionElement_isDropped() throws {
    // alternatives[0] has an out-of-set card → dropped; the valid sibling survives, no throw.
    let dto = WireFixtures.dailyBrief(alternatives: [
      WireFixtures.session(card: .unknown("new_card")),
      WireFixtures.session(card: .known(.activeRecovery)),
    ])
    let brief = try domainDailyBrief(dto)
    XCTAssertEqual(brief.alternatives.count, 1)
    XCTAssertEqual(brief.alternatives.first?.card, .activeRecovery)
  }

  func test_outOfSetCard_inRequiredSingular_throws() {
    let dto = WireFixtures.dailyBrief(sessionCard: .unknown("new_card"))
    XCTAssertThrowsError(try domainDailyBrief(dto)) { error in
      XCTAssertEqual(
        error as? MappingError,
        .unmappableRequiredEnum(field: "session.card", rawValue: "new_card")
      )
    }
  }

  func test_outOfSetBand_inRequiredSingular_throws() {
    let dto = WireFixtures.dailyBrief(band: .unknown("teal"))
    XCTAssertThrowsError(try domainDailyBrief(dto)) { error in
      XCTAssertEqual(
        error as? MappingError,
        .unmappableRequiredEnum(field: "readiness.band", rawValue: "teal")
      )
    }
  }

  func test_outOfSetDayType_inRequiredSingular_throws() {
    var dto = WireFixtures.dailyBrief()
    dto.data.macroFocus.dayType = .unknown("feast")
    XCTAssertThrowsError(try domainDailyBrief(dto)) { error in
      XCTAssertEqual(
        error as? MappingError,
        .unmappableRequiredEnum(field: "macroFocus.dayType", rawValue: "feast")
      )
    }
  }

  func test_outOfSetOptionalEnum_fallsBackToNil() throws {
    // An out-of-set value in an optional singular field → nil (not a throw, not a crash).
    var dto = WireFixtures.dailyBrief()
    dto.data.session.zoneTarget = .unknown("z9")
    let brief = try domainDailyBrief(dto)
    XCTAssertNil(brief.session.zoneTarget)
  }

  func test_outOfSetNarrativeType_inCollection_isDropped() throws {
    var dto = WireFixtures.dailyBrief()
    dto.narrative[0].type = .unknown("limerick")
    let brief = try domainDailyBrief(dto)
    XCTAssertEqual(brief.narrative, [])
  }

  // MARK: - Weekly plan

  func test_weeklyPlan_fullyPopulated_carriesEveryField() throws {
    let plan = try domainWeeklyPlan(WireFixtures.weeklyPlan())
    // Full-struct equality — totality enforced structurally (see daily-brief note above).
    XCTAssertEqual(plan, DomainFixtures.weeklyPlan())
  }

  func test_weeklyPlan_nilRestDayAndLastWeek_mapToNil() throws {
    let plan = try domainWeeklyPlan(WireFixtures.weeklyPlan(restDay: nil, lastWeek: nil))
    XCTAssertNil(plan.nutrition.restDay)
    XCTAssertNil(plan.nutrition.lastWeek)
  }

  func test_outOfSetPlannedSession_inCollection_isDropped() throws {
    // A planned session with an out-of-set card is dropped (collection element), no crash/throw.
    var dto = WireFixtures.weeklyPlan()
    dto.data.core[0].card = .unknown("new_card")
    let plan = try domainWeeklyPlan(dto)
    XCTAssertEqual(plan.core, [])
  }

  func test_outOfSetDayTypePattern_inCollection_isDropped() throws {
    var dto = WireFixtures.weeklyPlan()
    dto.data.nutrition.dayTypePattern[0].dayType = .unknown("feast")
    let plan = try domainWeeklyPlan(dto)
    XCTAssertEqual(plan.nutrition.dayTypePattern, [])
  }
}
