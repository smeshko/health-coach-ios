import DevSettings
import ProfileRepository
import SampleData

public extension ProfileRepository {
  /// The composition-root factory (ARCHITECTURE §7.1 / D25): per call, serves `.live` (network + GRDB,
  /// over the process-wide recompute stream) or the canned `SampleData` profile, keyed off
  /// `DevSettings.useMockData()`. The fetch closures (`profile` / `refresh` / `zones`) route per call;
  /// the recompute stream + emitter pass through the **live** value (the single shared continuation —
  /// routing a stream per call would re-mint it). RELEASE compiles the mock arm out.
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
        refresh: {
          try await devRoute(
            dev, .profile,
            live: { try await live.refresh() },
            mock: { scenario in try await Self.mock(scenario: scenario).refresh() }
          )
        },
        zones: {
          try await devRoute(
            dev, .profile,
            live: { try await live.zones() },
            mock: { scenario in try await Self.mock(scenario: scenario).zones() }
          )
        },
        recomputeNotices: live.recomputeNotices,
        noteRecompute: live.noteRecompute
      )
    #else
      return .liveValue
    #endif
  }
}
