import DevSettings
import Foundation
import SampleData
import XCTest

@testable import DevSettingsLive

final class DevSettingsLiveTests: XCTestCase {
  /// A throwaway, isolated UserDefaults suite (cleared up front) so tests never touch `.standard`.
  private func freshSuite(_ name: String = #function) -> (UserDefaults, String) {
    let suiteName = "DevSettingsLiveTests.\(name)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
  }

  func test_flag_persistsAcrossInstances() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let writer = DevSettings.live(store: DevSettingsStore(defaults: suite))
    writer.setUseMockData(true)

    let reader = DevSettings.live(store: DevSettingsStore(defaults: suite))
    XCTAssertTrue(reader.useMockData())
  }

  func test_scenario_persistsAndRoundTrips() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let writer = DevSettings.live(store: DevSettingsStore(defaults: suite))
    writer.setScenario(.dailyBriefAmber, .dailyBrief)

    let reader = DevSettings.live(store: DevSettingsStore(defaults: suite))
    XCTAssertEqual(reader.scenario(.dailyBrief), .dailyBriefAmber)
  }

  func test_missingScenario_fallsBackToDefault() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    XCTAssertEqual(dev.scenario(.profile), DevEndpoint.profile.defaultScenario)
  }

  func test_garbageScenario_fallsBackToDefault() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    suite.set(
      [DevEndpoint.dailyBrief.rawValue: "not_a_real_scenario"],
      forKey: DevSettingsStore.scenariosKey
    )
    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    XCTAssertEqual(dev.scenario(.dailyBrief), DevEndpoint.dailyBrief.defaultScenario)
  }

  func test_launchArg_beatsEnv_beatsPersisted() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }
    let store = DevSettingsStore(defaults: suite)

    // arg=true beats env=0 beats persisted=false.
    store.writeMock(false)
    DevSettings.applyLaunchOverrides(
      environment: ["COACH_MOCK": "0"],
      arguments: ["useMockData": "true"],
      defaults: suite
    )
    XCTAssertTrue(store.readMock(), "launch arg should win")

    // env beats persisted when no arg.
    store.writeMock(false)
    DevSettings.applyLaunchOverrides(
      environment: ["COACH_MOCK": "1"],
      arguments: [:],
      defaults: suite
    )
    XCTAssertTrue(store.readMock(), "env should win over persisted")

    // persisted is honoured when neither arg nor env is set.
    store.writeMock(false)
    DevSettings.applyLaunchOverrides(environment: [:], arguments: [:], defaults: suite)
    XCTAssertFalse(store.readMock(), "persisted false should be honoured")

    // DEBUG default is true when nothing is set.
    suite.removePersistentDomain(forName: name)
    DevSettings.applyLaunchOverrides(environment: [:], arguments: [:], defaults: suite)
    XCTAssertTrue(store.readMock(), "DEBUG default should be true")
  }

  func test_scenarioEnvVar_seedsSlot() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    DevSettings.applyLaunchOverrides(
      environment: ["COACH_SCENARIO_DAILYBRIEF": "dailyBriefRed"],
      arguments: [:],
      defaults: suite
    )
    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    XCTAssertEqual(dev.scenario(.dailyBrief), .dailyBriefRed)
  }
}
