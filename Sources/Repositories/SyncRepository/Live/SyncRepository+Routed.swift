import DevSettings
import SampleData
import SyncRepository

public extension SyncRepository {
  /// The composition-root factory (ARCHITECTURE §7.1 / D25): per call, serves `.live` (HealthKit +
  /// network + GRDB) or the canned `SampleData` sync result, keyed off `DevSettings.useMockData()`.
  /// Sync's mock has a single fixed scenario (`SyncScenario.success`), so the `.sync` endpoint's
  /// `SampleScenario` selection is not used here. RELEASE compiles the mock arm out.
  static func routed(_ dev: DevSettings) -> SyncRepository {
    #if DEBUG
      let live = Self.live
      let mock = Self.mock()
      return SyncRepository(
        sync: {
          try await devRoute(
            dev, .sync,
            live: { try await live.sync() },
            mock: { _ in try await mock.sync() }
          )
        },
        lastSync: {
          try await devRoute(
            dev, .sync,
            live: { try await live.lastSync() },
            mock: { _ in try await mock.lastSync() }
          )
        },
        // Deliberately NOT routed: the dev-menu anchor reset targets the real watermark row
        // regardless of the mock toggle — resetting a mock would be a no-op surprise.
        resetWatermark: { try await live.resetWatermark() }
      )
    #else
      return .live
    #endif
  }
}
