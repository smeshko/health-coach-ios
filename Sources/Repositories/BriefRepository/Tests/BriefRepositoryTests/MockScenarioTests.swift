import DomainModels
import SampleData
import Testing

import BriefRepository

struct MockScenarioTests {
  @Test func test_mock_daily_returnsScenarioDomain() async throws {
    let dailyScenarios: [SampleScenario] = [
      .dailyBriefGreen, .dailyBriefAmber, .dailyBriefRed,
      .dailyBriefRestGIFlare, .dailyBriefRestIllness, .dailyBriefRestKnee,
      .dailyBriefNoFood,
    ]
    for scenario in dailyScenarios {
      let result = try await BriefRepository.mock(scenario: scenario).dailyBrief(false)
      try #expect(result == SampleData.dailyBrief(scenario).domain, "scenario \(scenario)")
    }
  }

  @Test func test_mock_weekly_returnsDeloadDomain() async throws {
    let result = try await BriefRepository.mock(scenario: .weeklyPlanDeload).weeklyBrief(nil, false)
    try #expect(result == SampleData.weeklyPlan(.weeklyPlanDeload).domain)
  }

  @Test func test_mock_emptyIntake_hasNilIntakeYesterday() async throws {
    let result = try await BriefRepository.mock(scenario: .dailyBriefNoFood).dailyBrief(false)
    #expect(result.intakeYesterday == nil, "the empty-intake scenario has no yesterday intake")
  }
}
