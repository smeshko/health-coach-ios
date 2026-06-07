import DevSettings
import Foundation
import SampleData

public extension DevSettings {
  /// Seeds persisted dev settings from launch args / env at startup. **DEBUG-only** — an empty no-op
  /// in RELEASE. Call this from the composition root (Epic 6.1) *before* resolving `@Dependency`.
  ///
  /// Mock-flag precedence (highest first): **launch arg → env-var → persisted value → DEBUG default
  /// (`true`)**. Only the resolved value is written back to the persisted key, so subsequent
  /// `liveValue` reads observe it.
  ///
  /// - Parameters:
  ///   - environment: env-var source — `COACH_MOCK` (`1/0/true/false/yes/no`) for the flag and
  ///     `COACH_SCENARIO_<ENDPOINT>` (e.g. `COACH_SCENARIO_DAILYBRIEF`) to seed a scenario slot. The
  ///     scenario value may be a `SampleScenario` rawValue (`daily_brief_red`) or its case name
  ///     (`dailyBriefRed`).
  ///   - arguments: the NSArgumentDomain mock flag as `["useMockData": "YES"|"NO"|...]`. Pass `nil`
  ///     (the default) to read the real argument domain via `defaults`; pass an explicit dict (incl.
  ///     `[:]` for "no arg") in tests.
  ///   - defaults: persistence store — `.standard` in production, an isolated suite in tests.
  static func applyLaunchOverrides(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String: String?]? = nil,
    defaults: UserDefaults = .standard
  ) {
    #if DEBUG
      let store = DevSettingsStore(defaults: defaults)

      let resolvedMock: Bool = if let argMock = launchArgMock(arguments: arguments, defaults: defaults) {
        argMock
      } else if let envMock = parseBool(environment["COACH_MOCK"]) {
        envMock
      } else if store.hasPersistedMock() {
        store.readMock()
      } else {
        true // DEBUG default: run on fixtures with zero backend
      }
      store.writeMock(resolvedMock)

      for endpoint in DevEndpoint.allCases {
        let key = "COACH_SCENARIO_\(endpoint.rawValue.uppercased())"
        if let token = environment[key], let scenario = SampleScenario(devToken: token) {
          store.setScenario(scenario, for: endpoint)
        }
      }
    #endif
  }

  #if DEBUG
    private static func launchArgMock(arguments: [String: String?]?, defaults: UserDefaults) -> Bool? {
      if let arguments {
        return parseBool(arguments["useMockData"] ?? nil)
      }
      // Real NSArgumentDomain: `-useMockData YES` lands under the bare `useMockData` key (distinct from
      // the persisted `coach.dev.useMockData`).
      guard defaults.object(forKey: "useMockData") != nil else { return nil }
      return defaults.bool(forKey: "useMockData")
    }

    private static func parseBool(_ raw: String?) -> Bool? {
      guard let raw else { return nil }
      return switch raw.lowercased() {
      case "1", "true", "yes": true
      case "0", "false", "no": false
      default: nil
      }
    }
  #endif
}

#if DEBUG
  extension SampleScenario {
    /// Resolve a dev-override token that may be either the `rawValue` (`daily_brief_red`) or the Swift
    /// case name (`dailyBriefRed`).
    init?(devToken token: String) {
      if let byRaw = SampleScenario(rawValue: token) {
        self = byRaw
      } else if let byName = SampleScenario.allCases.first(where: { String(describing: $0) == token }) {
        self = byName
      } else {
        return nil
      }
    }
  }
#endif
