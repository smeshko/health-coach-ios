import Foundation
import SampleData
import XCTest

@testable import DevSettings

/// A lock-guarded mutable backing for a fake `DevSettings` so a test can flip `useMockData` and the
/// selected scenario at runtime; the fake's closures read this box on every call.
private final class FakeDevBox: @unchecked Sendable {
  private let lock = NSLock()
  private var mock: Bool
  private var scenarios: [DevEndpoint: SampleScenario]

  init(mock: Bool, scenarios: [DevEndpoint: SampleScenario] = [:]) {
    self.mock = mock
    self.scenarios = scenarios
  }

  var useMock: Bool {
    get { lock.withLock { mock } }
    set { lock.withLock { mock = newValue } }
  }

  func scenario(_ endpoint: DevEndpoint) -> SampleScenario {
    lock.withLock { scenarios[endpoint] ?? endpoint.defaultScenario }
  }

  func setScenario(_ scenario: SampleScenario, _ endpoint: DevEndpoint) {
    lock.withLock { scenarios[endpoint] = scenario }
  }
}

private extension DevSettings {
  /// Builds a fake `DevSettings` whose closures read/write `box` live (per call).
  static func fake(_ box: FakeDevBox) -> DevSettings {
    DevSettings(
      useMockData: { box.useMock },
      scenario: { box.scenario($0) },
      setUseMockData: { box.useMock = $0 },
      setScenario: { box.setScenario($0, $1) }
    )
  }
}

/// A demo repository confined to the test target — proves the `routed(_:)` convention without a real
/// repo existing yet (those land in Phases 4.2–4.5).
private struct DemoRepo: Sendable {
  var value: @Sendable () async -> String

  static let live = DemoRepo { "live" }

  static func mock(scenario: SampleScenario) -> DemoRepo {
    DemoRepo { "mock:\(scenario.rawValue)" }
  }

  static func routed(_ dev: DevSettings) -> DemoRepo {
    #if DEBUG
      let live = Self.live
      return DemoRepo {
        await devRoute(
          dev, .dailyBrief,
          live: { await live.value() },
          mock: { scenario in await DemoRepo.mock(scenario: scenario).value() }
        )
      }
    #else
      return .live
    #endif
  }
}

final class DevSettingsRoutingTests: XCTestCase {
  func test_routed_servesLive_whenFlagOff() async {
    let dev = DevSettings.fake(FakeDevBox(mock: false))
    let result = await DemoRepo.routed(dev).value()
    XCTAssertEqual(result, "live")
  }

  func test_routed_servesMock_whenFlagOn() async {
    let box = FakeDevBox(mock: true, scenarios: [.dailyBrief: .dailyBriefAmber])
    let dev = DevSettings.fake(box)
    let result = await DemoRepo.routed(dev).value()
    XCTAssertEqual(result, "mock:\(SampleScenario.dailyBriefAmber.rawValue)")
  }

  func test_routed_switchesPerCall_noReconstruction() async {
    let box = FakeDevBox(mock: false, scenarios: [.dailyBrief: .dailyBriefGreen])
    let dev = DevSettings.fake(box)

    // Build the routed value ONCE.
    let repo = DemoRepo.routed(dev)

    let first = await repo.value()
    XCTAssertEqual(first, "live")

    // Flip the flag after construction — the SAME repo must now serve mock.
    box.useMock = true
    let second = await repo.value()
    XCTAssertEqual(second, "mock:\(SampleScenario.dailyBriefGreen.rawValue)")
  }

  func test_routed_followsScenarioChange() async {
    let box = FakeDevBox(mock: true, scenarios: [.dailyBrief: .dailyBriefGreen])
    let dev = DevSettings.fake(box)
    let repo = DemoRepo.routed(dev)

    let first = await repo.value()
    XCTAssertEqual(first, "mock:\(SampleScenario.dailyBriefGreen.rawValue)")

    // Change only the selected scenario; the mock arm must follow on the next call.
    box.setScenario(.dailyBriefRed, .dailyBrief)
    let second = await repo.value()
    XCTAssertEqual(second, "mock:\(SampleScenario.dailyBriefRed.rawValue)")
  }
}
