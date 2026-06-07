import DomainModels
@testable import WireDomainMapping
import WireModels
import XCTest

final class BriefMappingTests: XCTestCase {
  func test_dailyBrief_fullyPopulated_carriesEveryField() throws {
    let brief = try domainDailyBrief(WireFixtures.dailyBrief())

    XCTAssertEqual(brief.date, WireFixtures.day(2026, 6, 6))
    XCTAssertEqual(brief.readiness.score, 82)
    XCTAssertEqual(brief.readiness.band, .green)
    XCTAssertEqual(brief.readiness.penalties, [ReadinessPenalty(factor: .hrvBelowBaseline, points: 8)])
    XCTAssertEqual(brief.session.card, .easyRun)
    XCTAssertEqual(brief.session.intensity, .easy)
    XCTAssertEqual(brief.session.zoneTarget, .z2)
    // Free-string flags map to typed flags, unknown preserved verbatim.
    XCTAssertEqual(brief.session.flags, [.impact, .unknown("totally_new_flag")])
    XCTAssertEqual(brief.safetyGate.reasons, [.giFlare, .unknown("brand_new_reason")])
    XCTAssertEqual(brief.macroFocus.dayType, .moderate)
    XCTAssertEqual(brief.alternatives.count, 1)
    XCTAssertEqual(brief.alternatives.first?.card, .activeRecovery)
    XCTAssertEqual(brief.narrative.map(\.type), [.summary])
    XCTAssertEqual(brief.generatedAt, WireFixtures.generatedAt)
    XCTAssertEqual(brief.constitutionVersion, "v3")
    XCTAssertNotNil(brief.intakeYesterday)
    XCTAssertEqual(brief.intakeYesterday?.vsTarget.proteinHit, true)
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

  // MARK: - Weekly plan

  func test_weeklyPlan_fullyPopulated_carriesEveryField() throws {
    let plan = try domainWeeklyPlan(WireFixtures.weeklyPlan())
    XCTAssertEqual(plan.isoWeek, "2026-W24")
    XCTAssertEqual(plan.weekStart, WireFixtures.day(2026, 6, 8))
    XCTAssertEqual(plan.budgets.longRunKm, 18.0)
    XCTAssertEqual(plan.core.count, 1)
    XCTAssertEqual(plan.core.first?.card, .longRun)
    XCTAssertEqual(plan.core.first?.suggestedDay, .sun)
    XCTAssertEqual(plan.extras, [])
    XCTAssertEqual(plan.targets.totalRunKm, 45.0)
    XCTAssertEqual(plan.nutrition.dayTypePattern.count, 1)
    XCTAssertEqual(plan.nutrition.dayTypePattern.first?.dayType, .moderate)
    XCTAssertEqual(plan.nutrition.restDay?.caloriesKcal, 2200)
    XCTAssertEqual(plan.nutrition.lastWeek?.proteinHitDays, 5)
    XCTAssertEqual(plan.narrative.map(\.type), [.plan])
  }

  func test_weeklyPlan_nilRestDayAndLastWeek_mapToNil() throws {
    let plan = try domainWeeklyPlan(WireFixtures.weeklyPlan(restDay: nil, lastWeek: nil))
    XCTAssertNil(plan.nutrition.restDay)
    XCTAssertNil(plan.nutrition.lastWeek)
  }
}
