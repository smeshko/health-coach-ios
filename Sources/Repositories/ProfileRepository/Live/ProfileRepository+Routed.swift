import DevSettings
import ProfileRepository
import SampleData

public extension ProfileRepository {
  /// The composition-root factory (ARCHITECTURE §7.1 / D25): per call, serves `.live` (network + GRDB)
  /// or the canned `SampleData` profile, keyed off `DevSettings.useMockData()`. The fetch closures
  /// (`profile` / `zones`) route per call. RELEASE compiles the mock arm out.
  static func routed(_ dev: DevSettings) -> ProfileRepository {
    #if DEBUG
      let live = Self.liveValue
      return ProfileRepository(
        profile: {
          try await devRoute(
            dev, .profile,
            live: { try await live.profile() },
            mock: { scenario in try await Self.mock(scenario: scenario).profile() }
          )
        },
        zones: {
          try await devRoute(
            dev, .profile,
            live: { try await live.zones() },
            mock: { scenario in try await Self.mock(scenario: scenario).zones() }
          )
        }
      )
    #else
      return .liveValue
    #endif
  }
}
