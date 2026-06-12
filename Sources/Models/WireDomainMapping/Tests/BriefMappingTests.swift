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

  // NOTE: out-of-set closed-enum scenarios are no longer constructible at the mapping boundary —
  // the closed enums are shared wire↔domain and decode STRICTLY (Phase 11.3), so an out-of-set
  // value throws a `DecodingError` at the WireModels boundary and never reaches this mapping. That
  // strict-decode guard is covered by `WireModels` decode tests (DecodeRoundTripTests). The mapping
  // helpers are now identity pass-throughs (EnumMappingTests).

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

}
