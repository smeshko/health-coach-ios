import SampleData
import Testing

@testable import DevSettings

struct DevEndpointTests {
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
}
