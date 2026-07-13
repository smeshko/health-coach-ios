import Clocks
import ComposableArchitecture
import DomainModels
import Foundation
import SampleData
import SyncRepository
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

  /// The ordering the cancellation can't cover (review #2.1): the save response crosses midnight
  /// while the scene stays CONTINUOUSLY ACTIVE — no `sceneBecameActive`, so no cancel. The
  /// day-scoped response clears the spinner only: no footer stamp, no delegate, no orchestration
  /// (which would stamp `contentDay` to today and permanently mask the rollover) — and the NEXT
  /// activation still detects the stale stamp and resets.
  @Test func test_saveCompletionAfterMidnight_doesNotMaskRollover() async {
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
      $0.checkInRepository.current = { _ in nil } // the eventual rollover re-gate: nothing saved
      $0.checkInRepository.save = { _ in
        for await _ in saveGate {} // resolves only after the clock rolls past midnight
      }
    }

    await store.send(.checkIn(.saveTapped)) { $0.checkIn.isSaving = true }
    clock.setValue(Self.postMidnight)
    saveRelease.finish() // the save resolves past midnight — scene continuously active, no cancel
    await store.receive(\.checkIn.saveResponse) { $0.checkIn.isSaving = false }
    #expect(store.state.checkIn.lastSavedAt == nil, "yesterday's save must not stamp today's footer")
    #expect(store.state.contentDay == Self.day, "no orchestration may move the stamp and mask the rollover")

    await store.send(.sceneBecameActive) {
      $0.checkIn = CheckInComponent.State()
      $0.contentDay = Self.newDay
    }
    await store.receive(\._checkInRequired) // the rollover still fires — nothing masked it
    await store.finish()
  }

  /// Review #3.2: the scene stays CONTINUOUSLY ACTIVE across midnight — `sceneBecameActive` never
  /// fires, so the first post-midnight save is what enters orchestration. The entry guard must reset
  /// the per-day state BEFORE the factory stamps `contentDay`: yesterday's `restoredSelection` (still
  /// among today's candidates here) must not seed today's carousel, and the stamp move must not mask
  /// the rollover.
  @Test func test_postMidnightSave_entryGuardResets_noStalePickSeed() async {
    let todayBrief: DomainModels.DailyBrief = {
      var sample = SampleData.dailyBriefGreen
      sample.date = Self.newDay
      sample.cached = false
      return sample
    }()
    let yesterdayPick = todayBrief.alternatives[0] // would hydrate selectedIndex 1 if it survived
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .checkInRequired,
        checkIn: CheckInComponent.State(giSymptoms: true, kneePain: 4),
        restoredSelection: yesterdayPick,
        contentDay: Self.day
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(Self.postMidnight)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.save = { _ in } // persists under today's key (captured post-midnight)
      $0.checkInRepository.current = { _ in
        DomainModels.CheckIn(date: Self.newDay, giSymptoms: true, kneePain: 4, illness: false)
      }
      $0.sessionSelectionRepository.current = { _ in nil } // no pick persisted for the new day
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in todayBrief }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.checkIn(.saveTapped)) { $0.checkIn.isSaving = true }
    await store.receive(\.checkIn.saveResponse) {
      $0.checkIn.isSaving = false
      $0.checkIn.lastSavedAt = Self.postMidnight
    }
    // The delegate enters orchestration: the entry guard resets per-day state, THEN the factory stamps.
    await store.receive(\.checkIn.delegate) {
      $0.checkIn = CheckInComponent.State()
      $0.restoredSelection = nil
      $0.contentDay = Self.newDay
    }
    await receiveSuccessChain(
      store, brief: todayBrief, freshness: .fresh, now: Self.postMidnight, zones: sampleZones()
    )
    #expect(store.state.session?.selectedIndex == 0, "yesterday's pick must not seed today's carousel")
  }

  /// Review #3.2, retry variant: a post-midnight `retryTapped` from yesterday's terminal (scene
  /// continuously active) resets via the entry guard and re-gates the new day with a CLEAN check-in
  /// child — yesterday's residual answers, footer state, and restored pick are all gone.
  @Test func test_postMidnightRetry_entryGuardResets_reGatesClean() async {
    let yesterdayRecord = DomainModels.CheckIn(date: Self.day, giSymptoms: true, kneePain: 4, illness: true)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .error(.transientGenerationFailed),
        checkIn: CheckInComponent.State(
          giSymptoms: true, illness: true, kneePain: 4,
          existing: yesterdayRecord, lastSavedAt: Self.preMidnight
        ),
        restoredSelection: SampleData.dailyBriefGreen.alternatives[0],
        contentDay: Self.day
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(Self.postMidnight)
      $0.checkInRepository.current = { _ in nil } // the new day's gate check: nothing saved
    }

    await store.send(.retryTapped) {
      $0.checkIn = CheckInComponent.State()
      $0.restoredSelection = nil
      $0.contentDay = Self.newDay
    }
    await store.receive(\._checkInRequired) { $0.briefState = .checkInRequired }
  }
}
