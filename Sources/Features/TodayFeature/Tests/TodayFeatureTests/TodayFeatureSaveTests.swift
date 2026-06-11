import Clocks
import CoachCore
import ComposableArchitecture
import SyncRepository
import Testing

@testable import TodayFeature

/// Coverage (ARCHITECTURE D18) of the save-triggered orchestration and the cancellation contract:
/// "Save & build today's brief" re-enters the sync→brief chain with `refresh: true` — both from the
/// `.checkInRequired` gate (the first save of the day) and from `.ready` (an edited check-in regenerates
/// the brief); and a new trigger **cancels** the in-flight orchestration so only the newer run's result
/// lands (§11).
@MainActor
struct TodayFeatureSaveTests {
  @Test func test_saveFromGate_runsOrchestration_withRefreshTrue() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let recorder = RefreshFlagRecorder()
    let store = TestStore(initialState: TodayFeature.State(briefState: .checkInRequired)) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      // The save has persisted by the time the chain re-reads the gate.
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.checkInRepository.save = { _ in }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { refresh in
        await recorder.record(refresh)
        return fresh
      }
    }

    await store.send(.checkIn(.saveTapped)) { $0.checkIn.saveStatus = .saving }
    await store.receive(\.checkIn.saveResponse) {
      $0.checkIn.saveStatus = .saved
      $0.checkIn.lastSavedAt = now
    }
    // The delegate re-enters the chain: gate (now unlocked) → sync → brief.
    await store.receive(\.checkIn.delegate)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) {
      $0.briefState = .ready(fresh, .fresh)
      $0.readiness = ReadinessComponent.State(readiness: fresh.readiness)
    }

    let flags = await recorder.flags
    #expect(flags == [true], "the save path regenerates via dailyBrief(refresh: true)")
  }

  @Test func test_editCheckIn_thenSave_regeneratesBriefFromReady() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let recorder = RefreshFlagRecorder()
    let store = TestStore(initialState: TodayFeature.State(briefState: .ready(fresh, .cached))) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.checkInRepository.save = { _ in }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { refresh in
        await recorder.record(refresh)
        return fresh
      }
    }

    // Edit + re-save with a brief already shown → the chain re-runs and a fresh brief replaces the cache.
    await store.send(.checkIn(.saveTapped)) { $0.checkIn.saveStatus = .saving }
    await store.receive(\.checkIn.saveResponse) {
      $0.checkIn.saveStatus = .saved
      $0.checkIn.lastSavedAt = now
    }
    await store.receive(\.checkIn.delegate)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) {
      $0.briefState = .ready(fresh, .fresh)
      $0.readiness = ReadinessComponent.State(readiness: fresh.readiness)
    }

    let flags = await recorder.flags
    #expect(flags == [true], "a re-save regenerates via dailyBrief(refresh: true)")
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
      $0.continuousClock = clock // the loading-phase min-dwell sleeps ride the same TestClock
      $0.checkInRepository.current = { _ in sampleCheckIn() }
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

    // Only the second run resolves. The 1s advance completes both its sync sleep and the concurrent
    // `.syncing` min-dwell (both started together); the second advance drains the `.generating` dwell.
    await clock.advance(by: .seconds(1))
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await clock.advance(by: TodayFeature.loadingPhaseMinDuration)
    await store.receive(\._briefResolved) {
      $0.briefState = .ready(fresh, .fresh)
      $0.readiness = ReadinessComponent.State(readiness: fresh.readiness)
    }

    let count = await syncCount.count
    #expect(count == 2, "both runs invoked sync(); the first was cancelled before resolving")
  }
}
