import DevSettings
import Foundation
import SampleData
import XCTest

@testable import DevSettingsLive

final class DevSettingsLogCategoryTests: XCTestCase {
  /// A throwaway, isolated UserDefaults suite (cleared up front) so tests never touch `.standard`.
  private func freshSuite(_ name: String = #function) -> (UserDefaults, String) {
    let suiteName = "DevSettingsLogCategoryTests.\(name)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
  }

  func test_category_defaultsOff() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    XCTAssertFalse(dev.isLogCategoryEnabled("tca"))
    XCTAssertFalse(dev.isLogCategoryEnabled("lifecycle"))
  }

  func test_setEnabled_persistsAcrossInstances() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let writer = DevSettings.live(store: DevSettingsStore(defaults: suite))
    writer.setLogCategoryEnabled(true, "tca")

    // A fresh store over the same suite reads the persisted flag.
    let reader = DevSettings.live(store: DevSettingsStore(defaults: suite))
    XCTAssertTrue(reader.isLogCategoryEnabled("tca"))
  }

  func test_categories_areIsolated() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    dev.setLogCategoryEnabled(true, "tca")

    XCTAssertTrue(dev.isLogCategoryEnabled("tca"))
    XCTAssertFalse(dev.isLogCategoryEnabled("lifecycle"), "an unrelated category must stay off")
  }

  func test_setFalse_disablesAfterEnabled() {
    let (suite, name) = freshSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let dev = DevSettings.live(store: DevSettingsStore(defaults: suite))
    dev.setLogCategoryEnabled(true, "app")
    XCTAssertTrue(dev.isLogCategoryEnabled("app"))

    dev.setLogCategoryEnabled(false, "app")
    XCTAssertFalse(dev.isLogCategoryEnabled("app"))
  }

  func test_testValue_resolvesEveryCategoryOff() {
    // The interface `testValue` inherits the default-off closure (no persistence) — what features see.
    let dev = DevSettings.testValue
    XCTAssertFalse(dev.isLogCategoryEnabled("tca"))
    XCTAssertFalse(dev.isLogCategoryEnabled("app"))
  }
}
