import Dependencies
import SampleData
import Testing

@testable import DevSettings

struct DevEndpointTests {
  /// Every `DevEndpoint` has a `defaultScenario` that is a real `SampleScenario` case (compiles by
  /// symbol), and `testValue.scenario(_:)` resolves each endpoint to that default.
  @Test func test_everyEndpoint_hasResolvableDefault() {
    let dev = DevSettings.testValue
    for endpoint in DevEndpoint.allCases {
      // `defaultScenario` is a `SampleScenario` — assert it round-trips through its rawValue (proves
      // it's a genuine case, not an out-of-band value).
      #expect(SampleScenario(rawValue: endpoint.defaultScenario.rawValue) == endpoint.defaultScenario)
      #expect(dev.scenario(endpoint) == endpoint.defaultScenario)
    }
  }

  /// The per-endpoint `scenarios` lists partition `SampleScenario.allCases` (each scenario belongs to
  /// exactly one endpoint) and every endpoint's list contains its `defaultScenario`. Guards the dev
  /// menu's per-endpoint filtering against an orphaned/duplicated scenario when fixtures change.
  @Test func test_scenarios_partitionAllCasesAndContainDefault() {
    var seen: Set<SampleScenario> = []
    for endpoint in DevEndpoint.allCases {
      #expect(endpoint.scenarios.contains(endpoint.defaultScenario))
      for scenario in endpoint.scenarios {
        #expect(seen.insert(scenario).inserted, "\(scenario) is listed under more than one endpoint")
      }
    }
    #expect(seen == Set(SampleScenario.allCases), "every SampleScenario must belong to exactly one endpoint")
  }

  /// `@Dependency(\.devSettings)` resolves to the `testValue` (mock-on) inside a dependency scope.
  @Test func test_dependency_resolvesToTestValue() {
    withDependencies {
      $0.devSettings = .testValue
    } operation: {
      @Dependency(\.devSettings) var dev
      #expect(dev.useMockData())
      #expect(dev.scenario(.dailyBrief) == .dailyBriefGreen)
    }
  }
}
