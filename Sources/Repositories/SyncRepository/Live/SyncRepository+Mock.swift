import SampleData
import SyncRepository

/// Scenario selection for `SyncRepository.mock(scenario:)`. Minimal in v1 (`.success`); the enum
/// exists so a forced-failure or alternate-count scenario can be added later without changing the
/// signature (DECISIONS #3).
public enum SyncScenario: Sendable {
  case success
}

public extension SyncRepository {
  /// A fixture-backed sync value — returns a canned `SyncResult` from `SampleData`'s
  /// `sync_response.json` with **no HealthKit, no network, and no watermark write** (D25/§7.1). Phase
  /// 4.1's routing wrapper + previews use it to simulate a successful sync with the backend off.
  static func mock(scenario: SyncScenario = .success) -> SyncRepository {
    SyncRepository(
      sync: {
        switch scenario {
        case .success:
          try syncResult(SampleData.syncResponse())
        }
      },
      lastSync: {
        switch scenario {
        case .success:
          try syncResult(SampleData.syncResponse()).serverTime
        }
      }
    )
  }
}
