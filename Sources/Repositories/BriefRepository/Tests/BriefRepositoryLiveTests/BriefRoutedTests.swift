import BriefRepository
import BriefRepositoryLive
import DevSettings
import SampleData
import Testing

/// Proves `BriefRepository.routed(_:)` wires the mock arm to the selected `SampleData` scenario when
/// `useMockData()` is on (DEBUG). The mock-off → live branch is exercised by the generic `devRoute`
/// toggle test (`DevSettingsRoutingTests`); the live arm itself hits network + GRDB and is covered by
/// the cache-policy tests.
struct BriefRoutedTests {
  private func dev(mockOn: Bool, scenario: SampleScenario) -> DevSettings {
    DevSettings(
      useMockData: { mockOn },
      scenario: { _ in scenario },
      setUseMockData: { _ in },
      setScenario: { _, _ in }
    )
  }

  @Test func test_routed_mockOn_servesSelectedDailyFixture() async throws {
    let repo = BriefRepository.routed(dev(mockOn: true, scenario: .dailyBriefAmber))
    let brief = try await repo.dailyBrief(false)
    let expected = try SampleData.dailyBrief(.dailyBriefAmber).domain
    #expect(brief == expected)
  }

  @Test func test_routed_mockOn_servesWeeklyFixture() async throws {
    let repo = BriefRepository.routed(dev(mockOn: true, scenario: .weeklyPlanDeload))
    let plan = try await repo.weeklyBrief(nil, false)
    let expected = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    #expect(plan == expected)
  }
}
