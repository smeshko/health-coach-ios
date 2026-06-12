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

  /// One clamp expression (`min(10, max(0, value))`), three representative inputs: above-range clamps
  /// down to 10, below-range clamps up to 0, in-range passes through (DECISIONS #2).
  @Test(arguments: [
    (initial: 0, input: 15, expected: 10),
    (initial: 5, input: -2, expected: 0),
    (initial: 0, input: 7, expected: 7),
  ])
  func test_kneePainChanged_clampsTo0Through10(initial: Int, input: Int, expected: Int) async {
    let store = TestStore(initialState: CheckInComponent.State(kneePain: initial)) {
      CheckInComponent()
    }
    await store.send(.kneePainChanged(input)) { $0.kneePain = expected }
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
      // `lastSavedAt` is NOT seeded on load — the persisted check-in has only a day-key, not a save
      // instant (the footer shows day-relative copy for the loaded case, keyed off `existing`).
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
    await store.send(.saveTapped) { $0.isSaving = true }
    await store.receive(\.saveResponse) {
      $0.isSaving = false
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

    await store.send(.saveTapped) { $0.isSaving = true }
    await store.receive(\.saveResponse) { $0.isSaving = false }
    // No `.delegate(.checkInSaved)` — the exhaustive store fails on any unexpected received action.
  }

  /// D7 re-entry guard: a second `.saveTapped` while a save is in flight is a no-op — no second save
  /// effect, so no duplicate `checkInSaved` delegate (which would trigger a duplicate orchestration).
  @Test func test_saveTapped_whileSaving_isNoOp() async {
    let recorder = SaveRecorder()
    let gate = SaveGate()
    let instant = sofiaDate(year: 2026, month: 6, day: 10)
    let store = TestStore(initialState: CheckInComponent.State()) {
      CheckInComponent()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(instant)
      $0.checkInRepository.save = { checkIn in
        await recorder.record(checkIn)
        await gate.wait()
      }
    }

    await store.send(.saveTapped) { $0.isSaving = true }
    // Second tap while saving: guarded → no state change, no extra effect (exhaustive store enforces it).
    await store.send(.saveTapped)
    await gate.open()
    await store.receive(\.saveResponse) {
      $0.isSaving = false
      $0.lastSavedAt = instant
    }
    await store.receive(\.delegate, .checkInSaved)
    await store.finish()

    let saved = await recorder.saved
    #expect(saved.count == 1, "the re-entry guard prevents a duplicate save")
  }
}

/// A one-shot gate that lets a stubbed `save` effect suspend mid-flight (so a second `.saveTapped`
/// arrives while the first is in flight). Handles open-before-wait so the test can't deadlock.
private actor SaveGate {
  private var continuation: CheckedContinuation<Void, Never>?
  private var opened = false

  func wait() async {
    if opened { return }
    await withCheckedContinuation { continuation = $0 }
  }

  func open() {
    opened = true
    continuation?.resume()
    continuation = nil
  }
}
