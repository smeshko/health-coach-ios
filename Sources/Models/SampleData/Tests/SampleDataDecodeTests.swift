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
      case .weeklyPlanDeload:
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
  }

  @Test func test_noFood_hasNilIntake() throws {
    #expect(try SampleData.dailyBrief(.dailyBriefNoFood).domain.intakeYesterday == nil)
  }

  @Test func test_unknownFlag_survivesMapping() throws {
    let brief = try SampleData.dailyBrief(.dailyBriefNoFood).domain
    #expect(
      brief.session.flags.contains(.unknown("moon_phase")),
      "unknown flag must survive the map with its raw string: \(brief.session.flags)"
    )
  }

  @Test func test_deload_isFlagged() throws {
    let plan = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    #expect(plan.budgets.deload)
    #expect(plan.budgets.longRunKm == nil, "deload fixture has a null longRunKm")
  }
}
