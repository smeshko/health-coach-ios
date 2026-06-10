import Clocks
import CoachCore
import ComposableArchitecture
import SyncRepository
import Testing

@testable import TodayFeature

/// `TestClock`-driven coverage (ARCHITECTURE D18, the Swift/SPM build conventions) of the debounced Refresh and the
/// cancellation contract: two rapid `refreshTapped` collapse to **one** orchestration run that calls
/// `dailyBrief(refresh: true)` (PRD §8.6); a new trigger **cancels** the in-flight orchestration so only
/// the newer run's result lands (§11); and editing the check-in then refreshing regenerates the brief.
@MainActor
struct TodayFeatureRefreshTests {
  @Test func test_refreshDebounce_collapsesToOneRun_withRefreshTrue() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let recorder = RefreshFlagRecorder()
    let clock = TestClock()
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = clock
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { refresh in
        await recorder.record(refresh)
        return fresh
      }
    }

    // Two rapid taps — the first pending debounce window is cancelled by the second (cancelInFlight).
    await store.send(.refreshTapped)
    await store.send(.refreshTapped)
    // Nothing has run yet — the debounce window hasn't elapsed.
    await clock.advance(by: TodayFeature.refreshDebounceWindow)

    await store.receive(\._runOrchestration)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) { $0.briefState = .ready(fresh, .fresh) }

    let flags = await recorder.flags
    #expect(flags == [true], "exactly one run, calling dailyBrief(refresh: true)")
  }

  @Test func test_newTrigger_cancelsInFlightOrchestration_onlySecondResultLands() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let syncCount = BriefCallCounter()
    let clock = TestClock()
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = clock
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = {
        await syncCount.increment()
        // Suspend so a newer trigger can cancel this run mid-flight before it resolves.
        try await clock.sleep(for: .seconds(1))
        return sampleSyncResult()
      }
      $0.briefRepository.dailyBrief = { _ in fresh }
    }

    // First run starts and suspends inside sync().
    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }

    // A second trigger cancels the in-flight first run (cancelInFlight on .orchestration). The first
    // run's cancelled `sync()` throws CancellationError, but its `send(._syncFailed)` is dropped because
    // the task is cancelled — so NO stale terminal mutation lands (TCA's Send guards on Task.isCancelled).
    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) // briefState already .syncing → no change

    // Only the second run resolves.
    await clock.advance(by: .seconds(1))
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) { $0.briefState = .ready(fresh, .fresh) }

    let count = await syncCount.count
    #expect(count == 2, "both runs invoked sync(); the first was cancelled before resolving")
  }

  @Test func test_editCheckIn_thenRefresh_regeneratesBrief() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let recorder = RefreshFlagRecorder()
    let clock = TestClock()
    let store = TestStore(initialState: TodayFeature.State(briefState: .ready(fresh, .cached))) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = clock
      $0.checkInRepository.current = { _ in nil }
      $0.checkInRepository.save = { _ in }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { refresh in
        await recorder.record(refresh)
        return fresh
      }
    }

    // Save the check-in → the child emits `.checkInSaved` → the parent offers Refresh.
    await store.send(.checkIn(.saveTapped)) { $0.checkIn.saveStatus = .saving }
    await store.receive(\.checkIn.saveResponse) { $0.checkIn.saveStatus = .saved }
    await store.receive(\.checkIn.delegate) { $0.offerRefresh = true }

    // Refresh → re-runs sync then dailyBrief(refresh: true) → a fresh brief, clearing the affordance.
    await store.send(.refreshTapped)
    await clock.advance(by: TodayFeature.refreshDebounceWindow)
    await store.receive(\._runOrchestration)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) {
      $0.offerRefresh = false
      $0.briefState = .ready(fresh, .fresh)
    }

    let flags = await recorder.flags
    #expect(flags == [true], "the Refresh path regenerates via dailyBrief(refresh: true)")
  }
}
