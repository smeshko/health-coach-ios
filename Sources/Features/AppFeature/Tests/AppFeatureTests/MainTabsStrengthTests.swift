import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import StrengthTestFeature
import Testing

@testable import AppFeature

/// `TestStore` coverage for the Phase 10.4 MainTabs wiring: the due-state derivation (the single
/// deriver), the You-tab → push on `openStrengthTest`, and the pop + clear-both-flags on `saved`.
@MainActor
struct MainTabsStrengthTests {
  private func sofiaDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar.europeSofia.date(from: components)!
  }

  @Test func test_refreshDue_setsBothFlagsWhenDue() async {
    // now: ISO week 24; last test in the prior week → due → both the tab flag and the row flag set.
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let lastTest = DomainModels.StrengthTest(
      date: sofiaDate(year: 2026, month: 6, day: 1), maxPushups: 20, maxPullups: 5
    )
    let store = TestStore(initialState: MainTabs.State()) {
      MainTabs()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.strengthTestRepository.current = { _ in lastTest }
    }
    await store.send(.refreshDue)
    await store.receive(\.dueRefreshed) {
      $0.strengthTestDue = true
      $0.settingsRoot.strengthTestDue = true
    }
  }

  @Test func test_refreshDue_clearsBothFlagsWhenNotDue() async {
    // now: ISO week 24; last test earlier this same week → not due → both flags clear from true.
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let lastTest = DomainModels.StrengthTest(
      date: sofiaDate(year: 2026, month: 6, day: 8), maxPushups: 30, maxPullups: 8
    )
    var initial = MainTabs.State()
    initial.strengthTestDue = true
    initial.settingsRoot.strengthTestDue = true
    let store = TestStore(initialState: initial) {
      MainTabs()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.strengthTestRepository.current = { _ in lastTest }
    }
    await store.send(.refreshDue)
    await store.receive(\.dueRefreshed) {
      $0.strengthTestDue = false
      $0.settingsRoot.strengthTestDue = false
    }
  }

  @Test func test_openStrengthTest_pushesScreen() async {
    let store = TestStore(initialState: MainTabs.State()) {
      MainTabs()
    }
    await store.send(.settingsRoot(.delegate(.openStrengthTest))) {
      $0.settings.append(.strengthTest(StrengthTestFeature.State()))
    }
  }

  @Test func test_openStrengthTest_doubleTapDoesNotStackTwoScreens() async {
    // A rapid double-tap on the row must push only one editor (review round-2 #1).
    let store = TestStore(initialState: MainTabs.State()) {
      MainTabs()
    }
    await store.send(.settingsRoot(.delegate(.openStrengthTest))) {
      $0.settings.append(.strengthTest(StrengthTestFeature.State()))
    }
    // Already on top → the second tap is a no-op (no second element).
    await store.send(.settingsRoot(.delegate(.openStrengthTest)))
  }

  @Test func test_savedDelegate_popsScreenAndClearsBothFlags() async {
    var initial = MainTabs.State()
    initial.strengthTestDue = true
    initial.settingsRoot.strengthTestDue = true
    let store = TestStore(initialState: initial) {
      MainTabs()
    }
    await store.send(.settingsRoot(.delegate(.openStrengthTest))) {
      $0.settings.append(.strengthTest(StrengthTestFeature.State()))
    }
    let id = store.state.settings.ids.last!
    await store.send(.settings(.element(id: id, action: .strengthTest(.delegate(.saved))))) {
      $0.settings.pop(from: id)
      $0.strengthTestDue = false
      $0.settingsRoot.strengthTestDue = false
    }
  }
}
