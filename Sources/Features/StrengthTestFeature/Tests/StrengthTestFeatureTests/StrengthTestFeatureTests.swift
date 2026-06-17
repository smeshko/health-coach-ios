import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import StrengthTestFeature

@MainActor
struct StrengthTestFeatureTests {
  /// Noon on a wall-clock day in Europe/Sofia (avoids DST/midnight edges).
  private func sofiaDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar.europeSofia.date(from: components)!
  }

  @Test func testSeedsFromCurrentAndIsNotDueWhenLoggedThisIsoWeek() async {
    // now: 2026-06-10 (ISO week 24); logged: 2026-06-08 (same ISO week) → seed + not due.
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let logged = DomainModels.StrengthTest(
      date: sofiaDate(year: 2026, month: 6, day: 8), maxPushups: 30, maxPullups: 8
    )
    let store = TestStore(initialState: StrengthTestFeature.State(isDue: true)) {
      StrengthTestFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.strengthTestRepository.current = { _ in logged }
    }
    await store.send(.onAppear)
    await store.receive(\.loaded) {
      $0.maxPushups = 30
      $0.maxPullups = 8
      $0.isDue = false
    }
  }

  @Test func testIsDueWhenLastTestInPriorIsoWeek() async {
    // now: 2026-06-10 (ISO week 24); logged: 2026-06-01 (ISO week 23) → seed + due.
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let logged = DomainModels.StrengthTest(
      date: sofiaDate(year: 2026, month: 6, day: 1), maxPushups: 25, maxPullups: 6
    )
    let store = TestStore(initialState: StrengthTestFeature.State(isDue: false)) {
      StrengthTestFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.strengthTestRepository.current = { _ in logged }
    }
    await store.send(.onAppear)
    await store.receive(\.loaded) {
      $0.maxPushups = 25
      $0.maxPullups = 6
      $0.isDue = true
    }
  }

  @Test func testNoLastTestSeedsZeroAndIsDue() async {
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let store = TestStore(initialState: StrengthTestFeature.State(isDue: false)) {
      StrengthTestFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.strengthTestRepository.current = { _ in nil }
    }
    await store.send(.onAppear)
    await store.receive(\.loaded) {
      // maxPushups/maxPullups stay 0 (no test to seed from); isDue flips true.
      $0.isDue = true
    }
  }

  @Test func testStepperChangesClampToRange() async {
    let store = TestStore(initialState: StrengthTestFeature.State()) {
      StrengthTestFeature()
    }
    await store.send(.pushupsChanged(500)) { $0.maxPushups = 300 }
    await store.send(.pushupsChanged(-5)) { $0.maxPushups = 0 }
    await store.send(.pullupsChanged(12)) { $0.maxPullups = 12 }
    await store.send(.pullupsChanged(301)) { $0.maxPullups = 300 }
  }

  @Test func testSaveRecordsTestAndEmitsSavedDelegate() async {
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let saved = LockIsolated<[DomainModels.StrengthTest]>([])
    let store = TestStore(initialState: StrengthTestFeature.State(maxPushups: 42, maxPullups: 11, isDue: true)) {
      StrengthTestFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.strengthTestRepository.save = { test in saved.withValue { $0.append(test) } }
    }
    await store.send(.saveTapped) { $0.saveState = .saving }
    // `.saved` is set BEFORE the delegate so the view's `.success` haptic fires before the parent pops.
    await store.receive(\.saveSucceeded) { $0.saveState = .saved }
    await store.receive(\.delegate.saved)
    #expect(saved.value == [DomainModels.StrengthTest(date: now, maxPushups: 42, maxPullups: 11)])
  }
}
