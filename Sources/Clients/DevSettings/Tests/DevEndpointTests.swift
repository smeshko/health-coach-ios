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
