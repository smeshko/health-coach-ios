import BriefRepository
import Clocks
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import LogClient
import SampleData
import SyncRepository
import Testing

@testable import TodayFeature

/// Exhaustive `TestStore` coverage (ARCHITECTURE D18) for the morning orchestration: the **check-in
/// gate** (no check-in today → `.checkInRequired`, sync never called), **sync strictly before the
/// brief** (D15/§11), a sync failure **blocking** the brief (the brief stub is invoked 0 times,
/// D23/§8.2), the cache-hit `.ready(.cached)` resolve, the brief-error terminal, the load-bearing
/// **non-typed-throw** catch-all (a 401 from `sync()` is not a `SyncError`), retry from a blocked
/// state, the `.lifecycle` observability line, and the single-`_briefResolved`-payload reducer arm
/// (forced-REST gate, zones-failure degrade, swap-reset on re-hydration). The save-triggered re-entry
/// + cancellation suite is `TodayFeatureSaveTests`. The success-chain `receive` walk is the shared
/// `receiveSuccessChain` helper (Phase 11.4 D4 — one walk, parameterized variants).
@MainActor
struct TodayFeatureOrchestrationTests {
  /// The success chain reaches `.ready(.fresh)` AND emits the `.lifecycle` `onAppOpen` log line (the
  /// `.lifecycle` emission regressed once — keep it asserted, folded from the former log test).
  @Test func test_onAppOpen_success_syncThenBrief_readyFresh_emitsLifecycleLog() async {
    let recorder = LogRecorder()
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in fresh }
      $0.profileRepository.zones = { sampleZones() }
      $0.log = .recording(into: recorder)
    }

    await store.send(.onAppOpen)
    await receiveSuccessChain(store, brief: fresh, freshness: .fresh, now: now, zones: sampleZones())

    #expect(recorder.entries.contains { $0.category == .lifecycle && $0.message.contains("cache-first orchestration") })
  }

  @Test func test_syncFailure_blocksBrief_setsSyncFailed_briefNeverCalled() async {
    let counter = BriefCallCounter()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaInstant())
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
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
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in cached }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen)
    await receiveSuccessChain(store, brief: cached, freshness: .cached, now: now, zones: sampleZones())
  }

  @Test func test_briefError_setsErrorCase_notSyncFailed() async {
    let now = sofiaInstant()
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
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
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
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
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
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

  @Test func test_noCheckInToday_gatesChain_checkInRequired_syncNeverCalled() async {
    let syncCounter = BriefCallCounter()
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaInstant())
      $0.checkInRepository.current = { _ in nil } // nothing saved today → the gate
      $0.syncRepository.sync = {
        await syncCounter.increment()
        return sampleSyncResult()
      }
      $0.briefRepository.dailyBrief = { _ in sampleBrief(cached: false) }
    }

    await store.send(.onAppOpen)
    await store.receive(\._checkInRequired) { $0.briefState = .checkInRequired }

    let count = await syncCounter.count
    #expect(count == 0, "no check-in today → the chain stops at the gate; sync MUST NOT run")
  }

  @Test func test_retryFromSyncFailed_rerunsChain_reachesReady() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State(briefState: .syncFailed(.network))) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in fresh }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.retryTapped)
    await receiveSuccessChain(store, brief: fresh, freshness: .fresh, now: now, zones: sampleZones())
  }

  // MARK: - The single `_briefResolved` payload reducer arm (Phase 11.4 D2)

  /// A zones failure (`profileRepository.zones()` → nil) degrades silently: the brief still resolves to
  /// `.ready` and the session child hydrates, but `state.zones == nil` (no zone chip). The single
  /// `_briefResolved(brief, freshness, nil)` payload carries the nil through.
  @Test func test_zonesFailure_briefStillResolves_zonesNil() async {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in fresh }
      $0.profileRepository.zones = { throw BriefError.serverError } // fetch fails → try? → nil
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) {
      $0.briefState = .ready(fresh, .fresh)
      $0.zones = nil
      $0.readiness = ReadinessComponent.State(readiness: fresh.readiness)
      // Untripped day → the session child still hydrates, just with nil zones (no chip).
      $0.session = SessionFeature.State(
        session: fresh.session,
        alternatives: fresh.alternatives,
        skipOk: fresh.skipOk,
        narrative: fresh.narrative.filter { $0.type == .session },
        zones: nil
      )
    }
    #expect(store.state.zones == nil)
  }

  /// A tripped (forced-REST) brief through `_briefResolved`: readiness still hydrates, but the session
  /// child is `nil` (the forced-REST screen renders the inline `SafetyRestView` instead). Exercises the
  /// `safetyGate.triggered` arm that the success tests never hit.
  @Test func test_forcedRestBrief_resolved_sessionNil_readinessHydrated() async throws {
    let forced = try SampleData.dailyBrief(.dailyBriefRestGIFlare).domain
    #expect(forced.safetyGate.triggered)
    let store = TestStore(initialState: TodayFeature.State()) { TodayFeature() }

    await store.send(._briefResolved(forced, .fresh, sampleZones())) {
      $0.briefState = .ready(forced, .fresh)
      $0.zones = sampleZones()
      $0.readiness = ReadinessComponent.State(readiness: forced.readiness)
      // A tripped gate renders the forced-REST screen, so the session child stays nil.
      $0.session = nil
    }
  }

  /// Re-hydration resets the carousel selection: a second `_briefResolved` re-seeds the session child, so a
  /// stale `selectedIndex` is cleared back to the primary (the doc-comment claims it; this asserts it).
  @Test func test_reHydration_resetsSelection() async {
    let fresh = sampleBrief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) { TodayFeature() }

    await store.send(._briefResolved(fresh, .fresh, sampleZones())) {
      $0.briefState = .ready(fresh, .fresh)
      $0.zones = sampleZones()
      $0.readiness = ReadinessComponent.State(readiness: fresh.readiness)
      $0.session = expectedSessionState(fresh, zones: sampleZones())
    }
    // The athlete commits the first alternative (candidate 1) via the child reducer; the child tells the
    // parent its selection changed (persistence wiring lands in a later task).
    await store.send(.session(.cardSelected(index: 1))) {
      $0.session?.selectedIndex = 1
    }
    await store.receive(\.session.delegate, .selectionChanged(fresh.alternatives[0]))
    // A second resolve (e.g. a re-save) re-seeds the child from the brief, clearing the selection to primary.
    await store.send(._briefResolved(fresh, .fresh, sampleZones())) {
      $0.session = expectedSessionState(fresh, zones: sampleZones())
    }
    #expect(store.state.session?.selectedIndex == 0)
  }

  /// The Exercise/Nutrition segmented toggle (`sectionSelected`) is a pure-UI reducer arm — the one
  /// arm with no other coverage after the 11.4 consolidation. Initial state is idle + Exercise; the
  /// toggle flips `selectedSection` with no effect.
  @Test func test_initialState_idleExercise_andSectionToggle() async {
    let store = TestStore(initialState: TodayFeature.State()) { TodayFeature() }
    #expect(store.state.briefState == .idle)
    #expect(store.state.selectedSection == .exercise)

    await store.send(.sectionSelected(.nutrition)) { $0.selectedSection = .nutrition }
    await store.send(.sectionSelected(.exercise)) { $0.selectedSection = .exercise }
  }
}
