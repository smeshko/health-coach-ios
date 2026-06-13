import Dependencies
import DevSettings
import Foundation

extension DevSettings: DependencyKey {
  /// UserDefaults-backed live value. In DEBUG it reads/writes the persisted flag + scenario map; in
  /// RELEASE the whole mock mechanism is compiled out — `useMockData()` is hard-`false` (so routing
  /// collapses to `.live`), `scenario(_:)` is never consumed, and the writers are no-ops.
  public static var liveValue: DevSettings {
    #if DEBUG
      return .live(store: DevSettingsStore(defaults: .standard))
    #else
      return DevSettings(
        useMockData: { false },
        scenario: { $0.defaultScenario }, // never consumed in RELEASE
        setUseMockData: { _ in },
        setScenario: { _, _ in }
      )
    #endif
  }

  #if DEBUG
    /// Builds a UserDefaults-backed `DevSettings` over `store`. Shared by `liveValue` and tests so the
    /// persistence wiring is defined once.
    static func live(store: DevSettingsStore) -> DevSettings {
      DevSettings(
        useMockData: { store.readMock() },
        scenario: { store.scenario(for: $0) },
        setUseMockData: { store.writeMock($0) },
        setScenario: { store.setScenario($0, for: $1) },
        isLogCategoryEnabled: { store.isLogCategoryEnabled($0) },
        setLogCategoryEnabled: { store.setLogCategoryEnabled($0, for: $1) }
      )
    }
  #endif
}
