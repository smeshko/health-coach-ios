import DevSettings
import Foundation
import SampleData

/// Internal UserDefaults-backed persistence for the DEBUG dev settings. `@unchecked Sendable`:
/// `UserDefaults` is documented thread-safe and this box adds only a stateless typed encode/decode
/// behind a lock, so concurrent reads from the `@Sendable` `liveValue` closures are safe.
final class DevSettingsStore: @unchecked Sendable {
  /// Persisted flag key. Deliberately distinct from the NSArgumentDomain launch-arg key
  /// (`useMockData`) so `applyLaunchOverrides` can express "launch arg > persisted" precedence — if
  /// both shared one key the argument domain would shadow the persisted value.
  static let mockKey = "coach.dev.useMockData"
  /// Persisted scenario map key: `[DevEndpoint.rawValue: SampleScenario.rawValue]`.
  static let scenariosKey = "coach.dev.scenarios"

  private let defaults: UserDefaults
  private let lock = NSLock()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func readMock() -> Bool {
    lock.withLock { defaults.bool(forKey: Self.mockKey) }
  }

  func writeMock(_ value: Bool) {
    lock.withLock { defaults.set(value, forKey: Self.mockKey) }
  }

  /// The selected scenario for `endpoint`, falling back to `endpoint.defaultScenario` when the slot
  /// is missing or holds a stale/garbage rawValue (migration-tolerant; never crashes).
  func scenario(for endpoint: DevEndpoint) -> SampleScenario {
    lock.withLock {
      let map = defaults.dictionary(forKey: Self.scenariosKey) as? [String: String]
      guard let raw = map?[endpoint.rawValue], let scenario = SampleScenario(rawValue: raw) else {
        return endpoint.defaultScenario
      }
      return scenario
    }
  }

  func setScenario(_ scenario: SampleScenario, for endpoint: DevEndpoint) {
    lock.withLock {
      var map = (defaults.dictionary(forKey: Self.scenariosKey) as? [String: String]) ?? [:]
      map[endpoint.rawValue] = scenario.rawValue
      defaults.set(map, forKey: Self.scenariosKey)
    }
  }

  /// Whether the persisted flag slot exists (distinguishes "set to false" from "never set" for the
  /// override precedence).
  func hasPersistedMock() -> Bool {
    lock.withLock { defaults.object(forKey: Self.mockKey) != nil }
  }
}
