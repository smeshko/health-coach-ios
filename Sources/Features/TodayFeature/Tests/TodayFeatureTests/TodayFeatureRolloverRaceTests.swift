import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import TodayFeature

/// Review #1.1 coverage: `rolloverReset` is a pure state mutation, NOT an async barrier — the rollover
/// branch must also CANCEL the check-in child's in-flight effects. Without the cancellation, a
/// pre-midnight `current(day)` load or `save` suspended across midnight (the app freezes at any await
/// point when backgrounded) delivers into the freshly reset state: re-seeding yesterday's answers,
/// stamping `lastSavedAt` with the new day's clock, or firing a stale `checkInSaved` delegate for a
/// check-in persisted under yesterday's day key (→ a duplicate orchestration). Both tests suspend the
/// repo call on a gate, roll the day over, then release the gate and prove nothing is delivered.
@MainActor
struct TodayFeatureRolloverRaceTests {
  /// The Sofia day of the shared test instant (`sofiaInstant()`'s day), and the two sides of its
  /// midnight — nonisolated constants so the `@Sendable` repo stubs can capture them.
  private nonisolated static let day = Calendar.europeSofia.startOfDay(for: sofiaInstant())
  private nonisolated static let preMidnight = day.addingTimeInterval(23 * 3600 + 59 * 60) // 23:59
  private nonisolated static let postMidnight = day.addingTimeInterval(24 * 3600 + 60) // 00:01 next day
  private nonisolated static let newDay = Calendar.europeSofia.date(byAdding: .day, value: 1, to: day)!

  /// A pre-midnight load suspended across the rollover is cancelled: releasing it after the reset
  /// delivers NO `_currentLoaded`, so yesterday's record can never re-seed the reset child.
  @Test func test_dayRollover_cancelsInFlightCheckInLoad() async {
    let clock = LockIsolated(Self.preMidnight)
    let (loadGate, loadRelease) = AsyncStream.makeStream(of: Void.self)
    let yesterdayRecord = DomainModels.CheckIn(date: Self.day, giSymptoms: true, kneePain: 4, illness: true)
    let store = TestStore(
      initialState: TodayFeature.State(briefState: .checkInRequired, contentDay: Self.day)
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = DateGenerator { clock.value }
      $0.checkInRepository.current = { requested in
        guard requested == Self.day else { return nil } // the new day's gate check: nothing saved
        for await _ in loadGate {} // yesterday's load, suspended across midnight
        return yesterdayRecord
      }
    }

    await store.send(.checkIn(.task)) // the pre-midnight load starts and suspends on the gate
    clock.setValue(Self.postMidnight)
    await store.send(.sceneBecameActive) { $0.contentDay = Self.newDay }
    await store.receive(\._checkInRequired) // already `.checkInRequired` — the re-gate is a no-op
    loadRelease.finish() // the suspended load resumes — its send must be dropped (cancelled)
    await store.finish()
    #expect(
      store.state.checkIn == CheckInComponent.State(),
      "yesterday's load must not re-seed the reset check-in child"
    )
  }

  /// A pre-midnight save suspended across the rollover is cancelled: releasing it after the reset
  /// delivers NO `saveResponse` and NO `checkInSaved` delegate — the record persisted under
  /// yesterday's key, so the new day must still gate, with no "Last saved" stamp from today's clock.
  @Test func test_dayRollover_cancelsInFlightCheckInSave() async {
    let clock = LockIsolated(Self.preMidnight)
    let (saveGate, saveRelease) = AsyncStream.makeStream(of: Void.self)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .checkInRequired,
        checkIn: CheckInComponent.State(giSymptoms: true, kneePain: 4),
        contentDay: Self.day
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = DateGenerator { clock.value }
      $0.checkInRepository.current = { _ in nil } // the new day's gate check: nothing saved
      $0.checkInRepository.save = { _ in
        for await _ in saveGate {} // yesterday's save, suspended across midnight
      }
    }

    await store.send(.checkIn(.saveTapped)) { $0.checkIn.isSaving = true }
    clock.setValue(Self.postMidnight)
    await store.send(.sceneBecameActive) {
      $0.checkIn = CheckInComponent.State()
      $0.contentDay = Self.newDay
    }
    await store.receive(\._checkInRequired) // already `.checkInRequired` — the re-gate is a no-op
    saveRelease.finish() // the suspended save resumes — its response/delegate must be dropped
    await store.finish()
    #expect(
      store.state.checkIn.lastSavedAt == nil,
      "a pre-midnight save must not stamp the new day's footer or re-enter orchestration"
    )
  }
}
