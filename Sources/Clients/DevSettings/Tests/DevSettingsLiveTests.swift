import DevSettings
import Foundation
import SampleData
import Testing

@testable import DevSettingsLive

struct DevSettingsLiveTests {
  /// A throwaway, isolated UserDefaults suite (cleared up front) so tests never touch `.standard`.
  private func freshSuite(_ name: String = #function) -> (UserDefaults, String) {
    let suiteName = "DevSettingsLiveTests.\(name)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
  }

  @Test func test_flag_persistsAcrossInstances() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let writer = DevSettings.live(store: DevSettingsStore(defaults: suite))
    writer.setUseMockData(true)

    let reader = DevSettings.live(store: DevSettingsStore(defaults: suite))
    #expect(reader.useMockData())
  }

  @Test func test_scenario_persistsAndRoundTrips() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let writer = DevSettings.live(store: DevSettingsStore(defaults: suite))
    writer.setScenario(.dailyBriefAmber, .dailyBrief)

    let reader = DevSettings.live(store: DevSettingsStore(defaults: suite))
    #expect(reader.scenario(.dailyBrief) == .dailyBriefAmber)
  }

  @Test func test_missingScenario_fallsBackToDefault() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    #expect(dev.scenario(.profile) == DevEndpoint.profile.defaultScenario)
  }

  @Test func test_garbageScenario_fallsBackToDefault() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    suite.set(
      [DevEndpoint.dailyBrief.rawValue: "not_a_real_scenario"],
      forKey: DevSettingsStore.scenariosKey
    )
    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    #expect(dev.scenario(.dailyBrief) == DevEndpoint.dailyBrief.defaultScenario)
  }

  @Test func test_launchArg_beatsEnv_beatsPersisted() {
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
    #expect(store.readMock(), "launch arg should win")

    // env beats persisted when no arg.
    store.writeMock(false)
    DevSettings.applyLaunchOverrides(
      environment: ["COACH_MOCK": "1"],
      arguments: [:],
      defaults: suite
    )
    #expect(store.readMock(), "env should win over persisted")

    // persisted is honoured when neither arg nor env is set.
    store.writeMock(false)
    DevSettings.applyLaunchOverrides(environment: [:], arguments: [:], defaults: suite)
    #expect(!store.readMock(), "persisted false should be honoured")

    // DEBUG default is true when nothing is set.
    suite.removePersistentDomain(forName: name)
    DevSettings.applyLaunchOverrides(environment: [:], arguments: [:], defaults: suite)
    #expect(store.readMock(), "DEBUG default should be true")
  }

  @Test func test_overrides_canForceMockOff() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }
    let store = DevSettingsStore(defaults: suite)

    // launch arg=false beats env=1 and persisted=true (the whole point: a dev forcing mock OFF).
    store.writeMock(true)
    DevSettings.applyLaunchOverrides(
      environment: ["COACH_MOCK": "1"],
      arguments: ["useMockData": "false"],
      defaults: suite
    )
    #expect(!store.readMock(), "launch arg=false should force mock off over env + persisted")

    // env=false beats persisted=true when there is no launch arg.
    store.writeMock(true)
    DevSettings.applyLaunchOverrides(
      environment: ["COACH_MOCK": "no"],
      arguments: [:],
      defaults: suite
    )
    #expect(!store.readMock(), "env=false should force mock off over persisted")
  }

  @Test func test_scenarioEnvVar_seedsSlot() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    DevSettings.applyLaunchOverrides(
      environment: ["COACH_SCENARIO_DAILYBRIEF": "dailyBriefRed"],
      arguments: [:],
      defaults: suite
    )
    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    #expect(dev.scenario(.dailyBrief) == .dailyBriefRed)
  }
}
