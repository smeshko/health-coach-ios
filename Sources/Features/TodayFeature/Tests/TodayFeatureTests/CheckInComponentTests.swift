import CheckInRepository
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import TodayFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for `CheckInComponent` — the clamped `kneePain`
/// (out-of-range impossible, PRD §7.2 / DECISIONS #2), the `current`-seeded load, and the upsert-by-date
/// `save` (latest-wins) that emits `delegate(.checkInSaved)`. Repos are stubbed via `withDependencies`;
/// `\.calendar`/`\.date` are pinned to Europe/Sofia so the saved date is deterministic.
@MainActor
struct CheckInComponentTests {
  /// Records the `CheckIn`s passed to `CheckInRepository.save` so the test can assert the latest values
  /// + today's Europe/Sofia date reached the repo.
  private actor SaveRecorder {
    private(set) var saved: [DomainModels.CheckIn] = []
    func record(_ checkIn: DomainModels.CheckIn) { saved.append(checkIn) }
  }

  /// A wall-clock instant in Europe/Sofia (mirrors `CalendarTests.sofiaDate`).
  private func sofiaDate(year: Int, month: Int, day: Int, hour: Int = 9) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return Calendar.europeSofia.date(from: components)!
  }

  @Test func test_kneePainChanged_clampsHigh_to10() async {
    let store = TestStore(initialState: CheckInComponent.State()) {
      CheckInComponent()
    }
    await store.send(.kneePainChanged(15)) { $0.kneePain = 10 }
  }

  @Test func test_kneePainChanged_clampsLow_to0() async {
    let store = TestStore(initialState: CheckInComponent.State(kneePain: 5)) {
      CheckInComponent()
    }
    await store.send(.kneePainChanged(-2)) { $0.kneePain = 0 }
  }

  @Test func test_kneePainChanged_inRange_passesThrough() async {
    let store = TestStore(initialState: CheckInComponent.State()) {
      CheckInComponent()
    }
    await store.send(.kneePainChanged(7)) { $0.kneePain = 7 }
  }

  @Test func test_task_seedsFieldsFromCurrentCheckIn() async {
    let instant = sofiaDate(year: 2026, month: 6, day: 10)
    let stored = DomainModels.CheckIn(
      date: Calendar.europeSofia.startOfDay(for: instant),
      giSymptoms: true,
      kneePain: 3,
      illness: true
    )
    let store = TestStore(initialState: CheckInComponent.State()) {
      CheckInComponent()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(instant)
      $0.checkInRepository.current = { _ in stored }
    }

    await store.send(.task)
    await store.receive(\._currentLoaded) {
      $0.existing = stored
      $0.giSymptoms = true
      $0.illness = true
      $0.kneePain = 3
      // Footer's "Last saved" seeds from the loaded check-in's day-date (the model has no precise save
      // instant); a fresh save overwrites it with the wall-clock `\.date`.
      $0.lastSavedAt = stored.date
    }
  }

  @Test func test_task_noCheckIn_leavesDefaults() async {
    let store = TestStore(initialState: CheckInComponent.State()) {
      CheckInComponent()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2026, month: 6, day: 10))
      $0.checkInRepository.current = { _ in nil }
    }

    await store.send(.task)
    await store.receive(\._currentLoaded) // nil → no mutation
  }

  @Test func test_save_callsRepoWithLatestValues_andEmitsDelegate() async {
    let recorder = SaveRecorder()
    let instant = sofiaDate(year: 2026, month: 6, day: 10)
    let store = TestStore(initialState: CheckInComponent.State()) {
      CheckInComponent()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(instant)
      $0.checkInRepository.save = { checkIn in await recorder.record(checkIn) }
    }

    await store.send(.giSymptomsToggled(true)) { $0.giSymptoms = true }
    await store.send(.kneePainChanged(4)) { $0.kneePain = 4 }
    await store.send(.saveTapped) { $0.saveStatus = .saving }
    await store.receive(\.saveResponse) {
      $0.saveStatus = .saved
      // A successful save stamps the footer with the wall-clock instant (pinned `\.date`).
      $0.lastSavedAt = instant
    }
    await store.receive(\.delegate, .checkInSaved)
    await store.finish()

    let saved = await recorder.saved
    let expectedDate = Calendar.europeSofia.startOfDay(for: instant)
    #expect(saved == [DomainModels.CheckIn(date: expectedDate, giSymptoms: true, kneePain: 4, illness: false)])
  }

  @Test func test_saveFailure_revertsToIdle_noDelegate() async {
    struct SaveBoom: Error {}
    let store = TestStore(initialState: CheckInComponent.State()) {
      CheckInComponent()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2026, month: 6, day: 10))
      $0.checkInRepository.save = { _ in throw SaveBoom() }
    }

    await store.send(.saveTapped) { $0.saveStatus = .saving }
    await store.receive(\.saveResponse) { $0.saveStatus = .idle }
    // No `.delegate(.checkInSaved)` — the exhaustive store fails on any unexpected received action.
  }
}
