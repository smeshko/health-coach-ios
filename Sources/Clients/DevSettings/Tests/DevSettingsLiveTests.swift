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

  @Test func test_seedFirstLaunchDefault_seedsMockTrueWhenNothingPersisted() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }
    let store = DevSettingsStore(defaults: suite)
    #expect(!store.hasPersistedMock(), "precondition: nothing persisted")

    DevSettings.seedFirstLaunchDefault(defaults: suite)
    #expect(store.hasPersistedMock(), "seed should write the flag on first launch")
    #expect(store.readMock(), "DEBUG first-launch default should be true")
  }

  @Test func test_seedFirstLaunchDefault_doesNotClobberPersistedFalse() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }
    let store = DevSettingsStore(defaults: suite)

    // A dev who has toggled mock OFF has a persisted `false`; the seed must leave it untouched.
    store.writeMock(false)
    DevSettings.seedFirstLaunchDefault(defaults: suite)
    #expect(!store.readMock(), "seed must not overwrite an already-persisted value")
  }
}
