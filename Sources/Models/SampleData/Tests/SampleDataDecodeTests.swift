import DomainModels
import Foundation
@testable import SampleData
import WireModels
import XCTest

final class SampleDataDecodeTests: XCTestCase {
  func test_everyScenario_decodesViaWireModels() {
    for scenario in SampleScenario.allCases {
      XCTAssertNoThrow(try SampleData.jsonData(for: scenario), "missing resource: \(scenario)")
      switch scenario {
      case .weeklyPlanDeload:
        XCTAssertNoThrow(try SampleData.weeklyPlan(scenario), "\(scenario)")
      case .profile:
        XCTAssertNoThrow(try SampleData.profile(), "\(scenario)")
      case .syncResponse:
        XCTAssertNoThrow(try SampleData.syncResponse(), "\(scenario)")
      default:
        XCTAssertNoThrow(try SampleData.dailyBrief(scenario), "\(scenario)")
      }
    }
  }

  func test_everyDailyBrief_mapsToDomain() throws {
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
      XCTAssertEqual(brief.readiness.band, band, "\(scenario)")
    }

    // The three forced-REST scenarios carry a tripped gate with the expected reason.
    XCTAssertEqual(
      try SampleData.dailyBrief(.dailyBriefRestGIFlare).domain.safetyGate.reasons, [.giFlare]
    )
    XCTAssertEqual(
      try SampleData.dailyBrief(.dailyBriefRestIllness).domain.safetyGate.reasons, [.illness]
    )
    XCTAssertEqual(
      try SampleData.dailyBrief(.dailyBriefRestKnee).domain.safetyGate.reasons, [.kneePainHigh]
    )
  }

  func test_noFood_hasNilIntake() throws {
    XCTAssertNil(try SampleData.dailyBrief(.dailyBriefNoFood).domain.intakeYesterday)
  }

  func test_unknownFlag_survivesMapping() throws {
    let brief = try SampleData.dailyBrief(.dailyBriefNoFood).domain
    XCTAssertTrue(
      brief.session.flags.contains(.unknown("moon_phase")),
      "unknown flag must survive the map with its raw string: \(brief.session.flags)"
    )
  }

  func test_deload_isFlagged() throws {
    let plan = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    XCTAssertTrue(plan.budgets.deload)
    XCTAssertNil(plan.budgets.longRunKm, "deload fixture has a null longRunKm")
  }
}
