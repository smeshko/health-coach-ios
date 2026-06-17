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
    // now: 2026-06-10 (ISO week 24); logged: 2026-06-08 (same ISO week) → seed + loaded + not due.
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
      $0.loadState = .loaded
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
      $0.loadState = .loaded
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
      // maxPushups/maxPullups stay 0 (no test to seed from); loaded; isDue flips true.
      $0.loadState = .loaded
      $0.isDue = true
    }
  }

  @Test func testReadFailureGoesToFailedState() async {
    // A thrown `current` read must NOT masquerade as a saveable 0/0 empty test (review #1).
    struct ReadError: Error {}
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let store = TestStore(initialState: StrengthTestFeature.State()) {
      StrengthTestFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.strengthTestRepository.current = { _ in throw ReadError() }
    }
    await store.send(.onAppear)
    await store.receive(\.loadFailed) {
      $0.loadState = .failed
    }
  }

  @Test func testRetryAfterFailureReloads() async {
    struct ReadError: Error {}
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let logged = DomainModels.StrengthTest(
      date: sofiaDate(year: 2026, month: 6, day: 8), maxPushups: 12, maxPullups: 3
    )
    let succeed = LockIsolated(false)
    let store = TestStore(initialState: StrengthTestFeature.State(loadState: .failed)) {
      StrengthTestFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.strengthTestRepository.current = { _ in
        guard succeed.value else { throw ReadError() }
        return logged
      }
    }
    succeed.setValue(true)
    await store.send(.retryTapped) { $0.loadState = .loading }
    await store.receive(\.loaded) {
      $0.loadState = .loaded
      $0.maxPushups = 12
      $0.maxPullups = 3
      $0.isDue = false
    }
  }

  @Test func testLateLoadDoesNotClobberUserEdits() async {
    // The user edits before a slow read returns → the late `.loaded` must keep their values (review #1).
    // Once the form is touched it's the user's; the late load still derives `isDue` but reseeds nothing.
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let logged = DomainModels.StrengthTest(
      date: sofiaDate(year: 2026, month: 6, day: 1), maxPushups: 25, maxPullups: 6
    )
    let store = TestStore(initialState: StrengthTestFeature.State(loadState: .loaded, isDue: false)) {
      StrengthTestFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
    }
    await store.send(.pushupsChanged(50)) {
      $0.userEdited = true
      $0.maxPushups = 50
    }
    // The late read derives `isDue` (false → true) but must NOT reseed maxPushups (stays 50) or maxPullups
    // (stays 0) — exhaustive TestStore fails if either count changes.
    await store.send(.loaded(logged)) {
      $0.isDue = true
    }
  }

  @Test func testStepperChangesClampToRange() async {
    let store = TestStore(initialState: StrengthTestFeature.State(loadState: .loaded)) {
      StrengthTestFeature()
    }
    await store.send(.pushupsChanged(500)) {
      $0.userEdited = true
      $0.maxPushups = 300
    }
    await store.send(.pushupsChanged(-5)) { $0.maxPushups = 0 }
    await store.send(.pullupsChanged(12)) { $0.maxPullups = 12 }
    await store.send(.pullupsChanged(301)) { $0.maxPullups = 300 }
  }

  @Test func testSaveRecordsTestAndEmitsSavedDelegate() async {
    let now = sofiaDate(year: 2026, month: 6, day: 10)
    let saved = LockIsolated<[DomainModels.StrengthTest]>([])
    let store = TestStore(
      initialState: StrengthTestFeature.State(loadState: .loaded, maxPushups: 42, maxPullups: 11, isDue: true)
    ) {
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

  @Test func testCountChangesIgnoredWhileSaving() async {
    // A stepper edit during an in-flight save would be silently dropped on the pop → ignore it (review #2).
    // Start already `.saving` so no parked effect is needed to hold the window open.
    let store = TestStore(
      initialState: StrengthTestFeature.State(
        loadState: .loaded, maxPushups: 42, maxPullups: 11, isDue: true, saveState: .saving
      )
    ) {
      StrengthTestFeature()
    }
    await store.send(.pushupsChanged(99)) // ignored while saving → no state change
    await store.send(.pullupsChanged(1)) // ignored while saving → no state change
  }
}
