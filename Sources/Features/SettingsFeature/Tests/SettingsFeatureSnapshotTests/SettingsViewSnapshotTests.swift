// SettingsFeatureView snapshots (ARCHITECTURE D16): the production CONNECTION / APPLE HEALTH / PROFILE
// sections in the connected + all-shared, degraded (some-missing), and not-connected states, light +
// dark on the single reference device. `#if canImport(UIKit)`-guarded (empty module on the macOS host —
// SwiftUI image snapshots are UIKit-only). Runs on the iOS 26 simulator via `make test-snapshots`.

#if canImport(UIKit)
  import CoachTestSupport
  import ComposableArchitecture
  import DomainModels
  import Foundation
  import HealthKitClient
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import SettingsFeature

  @MainActor
  struct SettingsViewSnapshotTests {
    /// A fixed instant so the last-sync "Today, …" string is deterministic.
    private static let now = Date(timeIntervalSince1970: 1_780_900_000)
    private static let total = HealthStatusInference.displayedCategories.count

    private static func zones() -> DomainModels.Zones {
      .init(
        z1: .init(low: 100, high: 133),
        z2: .init(low: 134, high: 151),
        z3: .init(low: 152, high: 167),
        z4: .init(low: 168, high: 180),
        z5: .init(low: 181, high: 195)
      )
    }

    /// A fully-loaded state seeded directly (no live effects). HK counts derive from the pinned
    /// `displayedCategories` constant so they can't drift from a live load (round-2 #1).
    private static func loadedState(
      connection: SettingsFeature.ConnectionStatus,
      lastSync: Date?,
      missing: [HealthDataCategory]
    ) -> SettingsFeature.State {
      var state = SettingsFeature.State()
      state.load = .loaded
      state.connection.status = connection
      state.lastSync.lastSyncAt = lastSync
      state.health = SettingsFeature.HealthKitStatusState(
        available: true,
        sharedCount: total - missing.count,
        totalCount: total,
        missingCategories: missing
      )
      state.constants = SettingsFeature.ConstantsState(
        age: 34, zones: zones(), restingHrBpm: 48, hrvBaselineMs: 92, recomputeNoticeWeek: nil
      )
      return state
    }

    @Test func test_settingsConnected() {
      let state = Self.loadedState(connection: .connected(tokenSuffix: "6f2a"), lastSync: Self.now, missing: [])
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(Self.now)
      } operation: {
        assertCoachSnapshot(of: NavigationStack {
          SettingsFeatureView(store: Store(initialState: state) { SettingsFeature() })
        })
      }
    }

    @Test func test_settingsDegraded() {
      let state = Self.loadedState(
        connection: .connected(tokenSuffix: "6f2a"), lastSync: Self.now, missing: [.sleep, .vo2Max]
      )
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(Self.now)
      } operation: {
        assertCoachSnapshot(of: NavigationStack {
          SettingsFeatureView(store: Store(initialState: state) { SettingsFeature() })
        })
      }
    }

    @Test func test_settingsNotConnected() {
      let state = Self.loadedState(connection: .notConnected, lastSync: nil, missing: [.sleep, .vo2Max])
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(Self.now)
      } operation: {
        assertCoachSnapshot(of: NavigationStack {
          SettingsFeatureView(store: Store(initialState: state) { SettingsFeature() })
        })
      }
    }
  }
#endif
