import BriefRepository
import DevSettings
import SampleData

public extension BriefRepository {
  /// The composition-root factory (ARCHITECTURE §7.1 / D25): per call, serves `.live` (network + GRDB)
  /// or the selected `SampleData` fixture, keyed off `DevSettings.useMockData()` — so flipping the dev
  /// flag at runtime switches delegation instantly, no relaunch. RELEASE compiles the mock arm out
  /// (`#else return .live`). Daily and weekly route through their own `DevEndpoint` so each can carry a
  /// distinct scenario.
  static func routed(_ dev: DevSettings) -> BriefRepository {
    #if DEBUG
      let live = Self.live
      return BriefRepository(
        dailyBrief: { refresh in
          try await devRoute(
            dev, .dailyBrief,
            live: { try await live.dailyBrief(refresh) },
            mock: { scenario in try await Self.mock(scenario: scenario).dailyBrief(refresh) }
          )
        },
        cachedDailyBrief: {
          try await devRoute(
            dev, .dailyBrief,
            live: { try await live.cachedDailyBrief() },
            mock: { scenario in try await Self.mock(scenario: scenario).cachedDailyBrief() }
          )
        },
        weeklyBrief: { isoWeek, refresh in
          try await devRoute(
            dev, .weeklyPlan,
            live: { try await live.weeklyBrief(isoWeek, refresh) },
            mock: { scenario in try await Self.mock(scenario: scenario).weeklyBrief(isoWeek, refresh) }
          )
        }
      )
    #else
      return .live
    #endif
  }
}
