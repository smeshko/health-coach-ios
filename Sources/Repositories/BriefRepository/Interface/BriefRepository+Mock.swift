import DomainModels
import SampleData

public extension BriefRepository {
  /// A fixture-backed repository: serves the selected `SampleScenario`'s daily/weekly domain value
  /// with **no live dependency** (D25 — the same `SampleData` fixtures previews/snapshots use). The
  /// `4.1 routed(dev:)` wrapper installs this when `useMockData()` is on; `refresh` is ignored (mock
  /// has no regeneration — a re-call returns the same scenario).
  ///
  /// `SampleScenario` is shared across daily + weekly, so the `dailyScenario`/`weeklyScenario`
  /// helpers fall a non-matching scenario back to that kind's default fixture, so the in-scope
  /// accessor always has a matching fixture rather than throwing a missing-fixture error.
  static func mock(scenario: SampleScenario) -> BriefRepository {
    BriefRepository(
      dailyBrief: { _ in try SampleData.dailyBrief(dailyScenario(scenario)).domain },
      // The mock world always "has" today's brief cached, so the cache-first open serves the scenario's
      // daily fixture immediately (dev-menu scenarios stay coherent with the cache-first open).
      cachedDailyBrief: { try SampleData.dailyBrief(dailyScenario(scenario)).domain },
      weeklyBrief: { _, _ in try SampleData.weeklyPlan(weeklyScenario(scenario)).domain }
    )
  }
}

/// Daily scenarios pass through; any non-daily scenario falls back to the green default.
private func dailyScenario(_ scenario: SampleScenario) -> SampleScenario {
  switch scenario {
  case .dailyBriefGreen, .dailyBriefAmber, .dailyBriefRed, .dailyBriefRestGIFlare,
       .dailyBriefRestIllness, .dailyBriefRestKnee, .dailyBriefNoFood:
    scenario
  default:
    .dailyBriefGreen
  }
}

/// Weekly scenarios pass through; any non-weekly scenario falls back to the normal-week default.
private func weeklyScenario(_ scenario: SampleScenario) -> SampleScenario {
  switch scenario {
  case .weeklyPlanNormal, .weeklyPlanDeload:
    scenario
  default:
    .weeklyPlanNormal
  }
}
