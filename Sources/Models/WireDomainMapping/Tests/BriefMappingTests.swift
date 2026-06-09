import DomainModels
import Testing
import WireModels

@testable import WireDomainMapping

struct BriefMappingTests {
  @Test func test_dailyBrief_fullyPopulated_carriesEveryField() throws {
    let brief = try domainDailyBrief(WireFixtures.dailyBrief())
    // Full-struct equality enforces totality structurally — every field must match, so a future
    // same-typed field transposition (e.g. fatGLow/fatGHigh) cannot pass silently.
    #expect(brief == DomainFixtures.dailyBrief())
  }

  @Test func test_dailyBrief_nullIntakeYesterday_mapsToNil() throws {
    let brief = try domainDailyBrief(WireFixtures.dailyBrief(intakeYesterday: nil))
    #expect(brief.intakeYesterday == nil)
  }

  @Test func test_dailyBrief_emptyAlternatives_mapsToEmpty() throws {
    let brief = try domainDailyBrief(WireFixtures.dailyBrief(alternatives: []))
    #expect(brief.alternatives == [])
  }

  @Test func test_unknownFlag_survivesMapWithRawString() throws {
    // The epic's stated validation — an unknown flag carries its exact raw string through the map.
    let brief = try domainDailyBrief(WireFixtures.dailyBrief())
    #expect(brief.session.flags.contains(.unknown("totally_new_flag")))
  }

  // MARK: - Closed-enum out-of-set, by position (DECISIONS Decision 2)

  @Test func test_outOfSetCard_inCollectionElement_isDropped() throws {
    // alternatives[0] has an out-of-set card → dropped; the valid sibling survives, no throw.
    let dto = WireFixtures.dailyBrief(alternatives: [
      WireFixtures.session(card: .unknown("new_card")),
      WireFixtures.session(card: .known(.activeRecovery)),
    ])
    let brief = try domainDailyBrief(dto)
    #expect(brief.alternatives.count == 1)
    #expect(brief.alternatives.first?.card == .activeRecovery)
  }

  @Test func test_outOfSetCard_inRequiredSingular_throws() {
    let dto = WireFixtures.dailyBrief(sessionCard: .unknown("new_card"))
    let error = #expect(throws: MappingError.self) { try domainDailyBrief(dto) }
    #expect(
      error == .unmappableRequiredEnum(field: "session.card", rawValue: "new_card")
    )
  }

  @Test func test_outOfSetBand_inRequiredSingular_throws() {
    let dto = WireFixtures.dailyBrief(band: .unknown("teal"))
    let error = #expect(throws: MappingError.self) { try domainDailyBrief(dto) }
    #expect(
      error == .unmappableRequiredEnum(field: "readiness.band", rawValue: "teal")
    )
  }

  @Test func test_outOfSetDayType_inRequiredSingular_throws() {
    var dto = WireFixtures.dailyBrief()
    dto.data.macroFocus.dayType = .unknown("feast")
    let error = #expect(throws: MappingError.self) { try domainDailyBrief(dto) }
    #expect(
      error == .unmappableRequiredEnum(field: "macroFocus.dayType", rawValue: "feast")
    )
  }

  @Test func test_outOfSetOptionalEnum_fallsBackToNil() throws {
    // An out-of-set value in an optional singular field → nil (not a throw, not a crash).
    var dto = WireFixtures.dailyBrief()
    dto.data.session.zoneTarget = .unknown("z9")
    let brief = try domainDailyBrief(dto)
    #expect(brief.session.zoneTarget == nil)
  }

  @Test func test_outOfSetNarrativeType_inCollection_isDropped() throws {
    var dto = WireFixtures.dailyBrief()
    dto.narrative[0].type = .unknown("limerick")
    let brief = try domainDailyBrief(dto)
    #expect(brief.narrative == [])
  }

  // MARK: - Weekly plan

  @Test func test_weeklyPlan_fullyPopulated_carriesEveryField() throws {
    let plan = try domainWeeklyPlan(WireFixtures.weeklyPlan())
    // Full-struct equality — totality enforced structurally (see daily-brief note above).
    #expect(plan == DomainFixtures.weeklyPlan())
  }

  @Test func test_weeklyPlan_nilRestDayAndLastWeek_mapToNil() throws {
    let plan = try domainWeeklyPlan(WireFixtures.weeklyPlan(restDay: nil, lastWeek: nil))
    #expect(plan.nutrition.restDay == nil)
    #expect(plan.nutrition.lastWeek == nil)
  }

  @Test func test_outOfSetPlannedSession_inCollection_isDropped() throws {
    // A planned session with an out-of-set card is dropped (collection element), no crash/throw.
    var dto = WireFixtures.weeklyPlan()
    dto.data.core[0].card = .unknown("new_card")
    let plan = try domainWeeklyPlan(dto)
    #expect(plan.core == [])
  }

  @Test func test_outOfSetDayTypePattern_inCollection_isDropped() throws {
    var dto = WireFixtures.weeklyPlan()
    dto.data.nutrition.dayTypePattern[0].dayType = .unknown("feast")
    let plan = try domainWeeklyPlan(dto)
    #expect(plan.nutrition.dayTypePattern == [])
  }
}
