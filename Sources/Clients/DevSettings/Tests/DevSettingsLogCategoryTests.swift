import Foundation
import SampleData
import Testing

@testable import DevSettings

struct DevSettingsLogCategoryTests {
  /// A throwaway, isolated UserDefaults suite (cleared up front) so tests never touch `.standard`.
  private func freshSuite(_ name: String = #function) -> (UserDefaults, String) {
    let suiteName = "DevSettingsLogCategoryTests.\(name)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
  }

  @Test func test_category_defaultsOff() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    #expect(!dev.isLogCategoryEnabled("tca"))
    #expect(!dev.isLogCategoryEnabled("lifecycle"))
  }

  @Test func test_setEnabled_persistsAcrossInstances() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let writer = DevSettings.live(store: DevSettingsStore(defaults: suite))
    writer.setLogCategoryEnabled(true, "tca")

    // A fresh store over the same suite reads the persisted flag.
    let reader = DevSettings.live(store: DevSettingsStore(defaults: suite))
    #expect(reader.isLogCategoryEnabled("tca"))
  }

  @Test func test_categories_areIsolated() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    dev.setLogCategoryEnabled(true, "tca")

    #expect(dev.isLogCategoryEnabled("tca"))
    #expect(!dev.isLogCategoryEnabled("lifecycle"), "an unrelated category must stay off")
  }

  @Test func test_setFalse_disablesAfterEnabled() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    dev.setLogCategoryEnabled(true, "app")
    #expect(dev.isLogCategoryEnabled("app"))

    dev.setLogCategoryEnabled(false, "app")
    #expect(!dev.isLogCategoryEnabled("app"))
  }
}
