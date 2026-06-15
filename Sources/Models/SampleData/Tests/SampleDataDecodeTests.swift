import DomainModels
import Foundation
import Testing
import WireModels

@testable import SampleData

struct SampleDataDecodeTests {
  @Test func test_everyScenario_decodesViaWireModels() {
    for scenario in SampleScenario.allCases {
      #expect(throws: Never.self, "missing resource: \(scenario)") {
        try SampleData.jsonData(for: scenario)
      }
      switch scenario {
      case .weeklyPlanNormal, .weeklyPlanDeload:
        #expect(throws: Never.self, "\(scenario)") { try SampleData.weeklyPlan(scenario) }
      case .profile:
        #expect(throws: Never.self, "\(scenario)") { try SampleData.profile() }
      case .syncResponse:
        #expect(throws: Never.self, "\(scenario)") { try SampleData.syncResponse() }
      default:
        #expect(throws: Never.self, "\(scenario)") { try SampleData.dailyBrief(scenario) }
      }
    }
  }

  @Test func test_everyDailyBrief_mapsToDomain() throws {
    let expectedBands: [SampleScenario: DomainModels.ReadinessBand] = [
      .dailyBriefGreen: .green,
      .dailyBriefAmber: .amber,
      .dailyBriefRed: .red,
      .dailyBriefRestGIFlare: .red,
      .dailyBriefRestIllness: .red,
      .dailyBriefRestKnee: .amber,
      .dailyBriefNoFood: .green,
    ]
    // Audit gap: pin that the expected-band map covers EXACTLY the daily-brief scenarios — a newly
    // added daily scenario would otherwise dodge the semantic band pin silently.
    let dailyScenarios = SampleScenario.allCases.filter { $0.rawValue.hasPrefix("daily_brief_") }
    #expect(
      Set(expectedBands.keys) == Set(dailyScenarios),
      "every daily-brief scenario must carry an expected-band assertion"
    )
    for (scenario, band) in expectedBands {
      let brief = try SampleData.dailyBrief(scenario).domain
      #expect(brief.readiness.band == band, "\(scenario)")
    }

    // The three forced-REST scenarios carry a tripped gate with the expected reason.
    #expect(
      try SampleData.dailyBrief(.dailyBriefRestGIFlare).domain.safetyGate.reasons == [.giFlare]
    )
    #expect(
      try SampleData.dailyBrief(.dailyBriefRestIllness).domain.safetyGate.reasons == [.illness]
    )
    #expect(
      try SampleData.dailyBrief(.dailyBriefRestKnee).domain.safetyGate.reasons == [.kneePainHigh]
    )

    // Folded from test_noFood_hasNilIntake (audit MERGE): the no-food scenario maps to a nil yesterday
    // intake.
    let noFood = try SampleData.dailyBrief(.dailyBriefNoFood).domain
    #expect(noFood.intakeYesterday == nil)
    // Folded from test_unknownFlag_survivesMapping (audit MERGE): an unknown flag survives the map with
    // its raw string.
    #expect(
      noFood.session.flags.contains(.unknown("moon_phase")),
      "unknown flag must survive the map with its raw string: \(noFood.session.flags)"
    )
  }

  @Test func test_deload_isFlagged() throws {
    let plan = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    #expect(plan.budgets.deload)
    #expect(plan.budgets.longRunKm == nil, "deload fixture has a null longRunKm")
  }

  /// Audit gap: the sync_response fixture is only decode-checked elsewhere; pin a couple of its fields
  /// so a resource edit that changes the canned counts is caught.
  @Test func test_syncResponse_fixtureFields() throws {
    let response = try SampleData.syncResponse()
    #expect(response.recordsUpserted == 128)
    #expect(response.checkinSaved)
  }
}
