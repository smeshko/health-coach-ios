import DomainModels
import SampleData
import XCTest

import BriefRepository

final class MockScenarioTests: XCTestCase {
  func test_mock_daily_returnsScenarioDomain() async throws {
    let dailyScenarios: [SampleScenario] = [
      .dailyBriefGreen, .dailyBriefAmber, .dailyBriefRed,
      .dailyBriefRestGIFlare, .dailyBriefRestIllness, .dailyBriefRestKnee,
      .dailyBriefNoFood,
    ]
    for scenario in dailyScenarios {
      let result = try await BriefRepository.mock(scenario: scenario).dailyBrief(false)
      XCTAssertEqual(result, try SampleData.dailyBrief(scenario).domain, "scenario \(scenario)")
    }
  }

  func test_mock_weekly_returnsDeloadDomain() async throws {
    let result = try await BriefRepository.mock(scenario: .weeklyPlanDeload).weeklyBrief(nil, false)
    XCTAssertEqual(result, try SampleData.weeklyPlan(.weeklyPlanDeload).domain)
  }

  func test_mock_emptyIntake_hasNilIntakeYesterday() async throws {
    let result = try await BriefRepository.mock(scenario: .dailyBriefNoFood).dailyBrief(false)
    XCTAssertNil(result.intakeYesterday, "the empty-intake scenario has no yesterday intake")
  }
}
