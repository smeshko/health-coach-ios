#if DEBUG
  import DevSettings
  import Foundation
  import SampleData

  /// Internal UserDefaults-backed persistence for the DEBUG dev settings. **DEBUG-only** — the whole
  /// type is compiled out of RELEASE (nothing references it there; `liveValue`'s RELEASE branch is a
  /// hard-`false` no-op store with no persistence).
  ///
  /// `@unchecked Sendable` is sound because every access goes through a **shared static** `NSLock`,
  /// which serializes the scenario-map read-modify-write across *all* store instances over the same
  /// `UserDefaults` (a per-instance lock would not — `liveValue`, the first-launch seed, and tests
  /// each construct their own store). Contention is irrelevant: this is a DEBUG-only tool with rare
  /// writes.
  final class DevSettingsStore: @unchecked Sendable {
    /// Persisted mock-flag key. The first-launch seed writes it once when missing; the dev-menu toggle
    /// is the only control thereafter. `hasPersistedMock()` distinguishes "set to false" from "unset".
    static let mockKey = "coach.dev.useMockData"
    /// Persisted scenario map key: `[DevEndpoint.rawValue: SampleScenario.rawValue]`.
    static let scenariosKey = "coach.dev.scenarios"
    /// Persisted log-category enabled map key: `[LogCategory.rawValue: Bool]`. String-keyed so the
    /// store stays free of a `LogClient` import; `LogClientLive` maps `LogCategory.rawValue` in.
    static let logCategoriesKey = "coach.dev.logCategories"

    /// Shared across instances so the cross-instance scenario-map read-modify-write is serialized.
    private static let lock = NSLock()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
    }

    func readMock() -> Bool {
      Self.lock.withLock { defaults.bool(forKey: Self.mockKey) }
    }

    func writeMock(_ value: Bool) {
      Self.lock.withLock { defaults.set(value, forKey: Self.mockKey) }
    }

    /// The selected scenario for `endpoint`, falling back to `endpoint.defaultScenario` when the slot
    /// is missing or holds a stale/garbage rawValue (migration-tolerant; never crashes).
    func scenario(for endpoint: DevEndpoint) -> SampleScenario {
      Self.lock.withLock {
        let map = defaults.dictionary(forKey: Self.scenariosKey) as? [String: String]
        guard let raw = map?[endpoint.rawValue], let scenario = SampleScenario(rawValue: raw) else {
          return endpoint.defaultScenario
        }
        return scenario
      }
    }

    func setScenario(_ scenario: SampleScenario, for endpoint: DevEndpoint) {
      Self.lock.withLock {
        var map = (defaults.dictionary(forKey: Self.scenariosKey) as? [String: String]) ?? [:]
        map[endpoint.rawValue] = scenario.rawValue
        defaults.set(map, forKey: Self.scenariosKey)
      }
    }

    /// Whether the persisted flag slot exists (distinguishes "set to false" from "never set" — the
    /// first-launch seed only writes when this is false).
    func hasPersistedMock() -> Bool {
      Self.lock.withLock { defaults.object(forKey: Self.mockKey) != nil }
    }

    /// Whether the log category keyed by `rawValue` is enabled — **false** when the slot is missing
    /// (default-off; verbose categories stay quiet until explicitly toggled on).
    func isLogCategoryEnabled(_ rawValue: String) -> Bool {
      Self.lock.withLock {
        let map = defaults.dictionary(forKey: Self.logCategoriesKey) as? [String: Bool]
        return map?[rawValue] ?? false
      }
    }

    func setLogCategoryEnabled(_ enabled: Bool, for rawValue: String) {
      Self.lock.withLock {
        var map = (defaults.dictionary(forKey: Self.logCategoriesKey) as? [String: Bool]) ?? [:]
        map[rawValue] = enabled
        defaults.set(map, forKey: Self.logCategoriesKey)
      }
    }
  }
#endif
