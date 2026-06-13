import BriefRepository
import BriefRepositoryLive
import CoachTestSupport
import DevSettings
import Foundation
import SampleData
import Testing

/// Proves `BriefRepository.routed(_:)` wires the mock arm to the selected `SampleData` scenario when
/// `useMockData()` is on (DEBUG). The mock-off → live branch is exercised by the generic `devRoute`
/// toggle test (`DevSettingsRoutingTests`); the live arm itself hits network + GRDB and is covered by
/// the cache-policy tests.
struct BriefRoutedTests {
  /// A fake `DevSettings` whose `scenario` closure RECORDS the `DevEndpoint` it was asked about
  /// (audit WEAK fix — the old stub ignored the arg, so daily/weekly routed through the wrong endpoint
  /// would have passed). The recorder uses the shared `CallRecorder`.
  private func dev(
    mockOn: Bool, scenario: SampleScenario, recorder: CallRecorder<DevEndpoint>
  ) -> DevSettings {
    DevSettings(
      useMockData: { mockOn },
      scenario: { endpoint in
        recorder.record(endpoint)
        return scenario
      },
      setUseMockData: { _ in },
      setScenario: { _, _ in }
    )
  }

  @Test func test_routed_mockOn_servesSelectedDailyFixture_viaDailyEndpoint() async throws {
    let recorder = CallRecorder<DevEndpoint>()
    let repo = BriefRepository.routed(dev(mockOn: true, scenario: .dailyBriefAmber, recorder: recorder))
    let brief = try await repo.dailyBrief(false)
    let expected = try SampleData.dailyBrief(.dailyBriefAmber).domain
    #expect(brief == expected)
    #expect(recorder.lastArgument == .dailyBrief, "the daily route must resolve via the .dailyBrief endpoint")
  }

  @Test func test_routed_mockOn_servesWeeklyFixture_viaWeeklyEndpoint() async throws {
    let recorder = CallRecorder<DevEndpoint>()
    let repo = BriefRepository.routed(dev(mockOn: true, scenario: .weeklyPlanDeload, recorder: recorder))
    let plan = try await repo.weeklyBrief(nil, false)
    let expected = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    #expect(plan == expected)
    #expect(recorder.lastArgument == .weeklyPlan, "the weekly route must resolve via the .weeklyPlan endpoint")
  }
}
