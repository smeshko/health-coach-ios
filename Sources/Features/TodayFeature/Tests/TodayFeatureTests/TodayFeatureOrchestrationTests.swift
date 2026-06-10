import BriefRepository
import CoachCore
import ComposableArchitecture
import SyncRepository
import Testing

@testable import TodayFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for the morning orchestration: **sync strictly
/// before the brief** (D15/§11), a sync failure **blocking** the brief (the brief stub is invoked 0
/// times, D23/§8.2), the cache-hit `.ready(.cached)` resolve, the brief-error terminal, the load-bearing
/// **non-typed-throw** catch-all (a 401 from `sync()` is not a `SyncError`), the skip-check-in path, and
/// retry from a blocked state. The debounce + cancellation suite is TASK-004.
@MainActor
struct TodayFeatureOrchestrationTests {
  @Test func test_onAppOpen_success_syncThenBrief_readyFresh() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in fresh }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) { $0.briefState = .ready(fresh, .fresh) }
  }

  @Test func test_syncFailure_blocksBrief_setsSyncFailed_briefNeverCalled() async {
    let counter = BriefCallCounter()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaInstant())
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = { throw SyncError.network }
      $0.briefRepository.dailyBrief = { _ in
        await counter.increment()
        return fresh
      }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._syncFailed) { $0.briefState = .syncFailed(.network) }

    let count = await counter.count
    #expect(count == 0, "the brief MUST NOT be requested on a failed sync (D23/§11)")
  }

  @Test func test_cacheHit_resolvesReadyCached() async {
    let now = sofiaInstant()
    let cached = sampleBrief(cached: true)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in cached }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) { $0.briefState = .ready(cached, .cached) }
  }

  @Test func test_briefError_setsErrorCase_notSyncFailed() async {
    let now = sofiaInstant()
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in throw BriefError.serverError }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefFailed) { $0.briefState = .error(.serverError) }
  }

  @Test func test_nonTypedSyncThrow_landsSyncFailedFallback_briefNeverCalled() async {
    struct WeirdError: Error {}
    let counter = BriefCallCounter()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaInstant())
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = { throw WeirdError() } // e.g. the propagated 401 — NOT a SyncError (4.3)
      $0.briefRepository.dailyBrief = { _ in
        await counter.increment()
        return fresh
      }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._syncFailed) { $0.briefState = .syncFailed(.transient) }

    let count = await counter.count
    #expect(count == 0, "an unexpected throw must land a terminal state, never wedge on .syncing")
  }

  @Test func test_nonTypedBriefThrow_landsErrorFallback() async {
    struct WeirdError: Error {}
    let now = sofiaInstant()
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in throw WeirdError() }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefFailed) { $0.briefState = .error(.transientGenerationFailed) }
  }

  @Test func test_skipCheckIn_nilCurrent_stillReachesReady() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil } // no check-in logged — must not hard-block
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in fresh }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) { $0.briefState = .ready(fresh, .fresh) }
  }

  @Test func test_retryFromSyncFailed_rerunsChain_reachesReady() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State(briefState: .syncFailed(.network))) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in fresh }
    }

    await store.send(.retryTapped)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) { $0.briefState = .ready(fresh, .fresh) }
  }
}
