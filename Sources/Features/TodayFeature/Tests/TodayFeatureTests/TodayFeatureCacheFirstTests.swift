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

/// Phase 12.1 cache-first open coverage (revised D15): a same-day cache HIT renders `.ready(.cached)`
/// instantly (no loading wall, no clock advance) then refreshes quietly in the background, swapping the
/// result in **only if the content changed** (DECISIONS D3 — metadata-normalized equality + zone merge);
/// background failures degrade quietly (D6); pull-to-refresh and the scene-staleness gate reuse the same
/// background pass; Cancel falls back to the cached brief or `.syncFailed` (D4). Existing blocking-path
/// tests (`TodayFeatureOrchestrationTests`) stay green because `cachedDailyBrief` `testValue` is `nil`.
@MainActor
struct TodayFeatureCacheFirstTests {
  // MARK: - Helpers

  /// A green sample brief with the metadata fields pinned to a known value.
  private func brief(
    cached: Bool = true,
    generatedAt: Date? = nil,
    constitutionVersion: String? = nil,
    skipOk: Bool? = nil
  ) -> DomainModels.DailyBrief {
    var sample = SampleData.dailyBriefGreen
    sample.cached = cached
    if let generatedAt { sample.generatedAt = generatedAt }
    sample.constitutionVersion = constitutionVersion
    if let skipOk { sample.skipOk = skipOk }
    return sample
  }

  /// The session/readiness children the parent hydrates from a resolved brief (mirrors `hydrate`).
  private func expectedReadiness(_ sample: DomainModels.DailyBrief) -> ReadinessComponent.State {
    ReadinessComponent.State(readiness: sample.readiness)
  }

  // MARK: - Cache hit: instant open + flag flip (AC: cache hit, no loading)

  @Test func test_cacheHitOpen_rendersReadyCachedInstantly_noLoadingStates() async {
    let now = sofiaInstant()
    let cached = brief(cached: true)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.briefRepository.cachedDailyBrief = { cached }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in cached } // unchanged content → no swap
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen)
    // Instant cache render — NO `.syncing`/`.generating`, no clock advance.
    await store.receive(\._cachedBriefLoaded) {
      $0.briefState = .ready(cached, .cached)
      $0.readiness = expectedReadiness(cached)
      $0.session = SessionFeature.State(
        session: cached.session, alternatives: cached.alternatives, skipOk: cached.skipOk,
        narrative: cached.narrative.filter { $0.type == .session }, zones: nil
      )
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    // Background pass: sync records lastSyncedAt, then the unchanged brief just clears the flag + merges
    // the zones into the (already-hydrated) session child.
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.zones = sampleZones()
      $0.session?.zones = sampleZones()
      // Unchanged content (only generatedAt differs is false here — same fixture) → freshness reflects
      // the regenerated `cached == true` fixture, children untouched.
      $0.briefState = .ready(cached, .cached)
    }
  }

  // MARK: - Background swap: changed vs unchanged (AC: swap changed/unchanged)

  @Test func test_backgroundRefresh_changedBrief_swapsToFreshAndReseedsChildren() async {
    let now = sofiaInstant()
    let cached = brief(cached: true, skipOk: false)
    let changed = brief(cached: false, skipOk: true) // genuinely different content
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.briefRepository.cachedDailyBrief = { cached }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in changed }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen)
    await store.receive(\._cachedBriefLoaded) {
      $0.briefState = .ready(cached, .cached)
      $0.readiness = expectedReadiness(cached)
      $0.session = SessionFeature.State(
        session: cached.session, alternatives: cached.alternatives, skipOk: cached.skipOk,
        narrative: cached.narrative.filter { $0.type == .session }, zones: nil
      )
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.zones = sampleZones()
      // Changed content → full re-hydration to `.ready(.fresh)`, children re-seeded with merged zones.
      $0.briefState = .ready(changed, .fresh)
      $0.readiness = expectedReadiness(changed)
      $0.session = SessionFeature.State(
        session: changed.session, alternatives: changed.alternatives, skipOk: changed.skipOk,
        narrative: changed.narrative.filter { $0.type == .session }, zones: sampleZones()
      )
    }
  }

  /// A refresh differing ONLY in `generatedAt`/`cached` counts as unchanged — children untouched (the
  /// content-equality boundary, round-1 #1). Driven from a pre-`.ready` state via `pullToRefresh` so the
  /// child UI (why-toggle expanded) is established BEFORE the refresh, then asserted untouched after.
  @Test func test_backgroundRefresh_metadataOnlyChange_isUnchanged_childrenUntouched() async {
    let now = sofiaInstant()
    let cached = brief(cached: true, generatedAt: now.addingTimeInterval(-3600))
    let regenerated = brief(cached: false, generatedAt: now) // only generatedAt + cached differ
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(cached, .cached),
        readiness: ReadinessComponent.State(readiness: cached.readiness, isWhyExpanded: true),
        session: SessionFeature.State(
          session: cached.session, alternatives: cached.alternatives, skipOk: cached.skipOk,
          narrative: cached.narrative.filter { $0.type == .session }, zones: nil
        )
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in regenerated }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.pullToRefresh) {
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.zones = sampleZones()
      $0.session?.zones = sampleZones()
      // Metadata-only change → unchanged content → children untouched (why-toggle stays expanded), only
      // the freshness metadata updates (regenerated `cached == false` → `.fresh`).
      $0.briefState = .ready(regenerated, .fresh)
    }
    #expect(store.state.readiness?.isWhyExpanded == true, "an unchanged refresh must not reset child UI")
  }

  /// A brief differing ONLY in `constitutionVersion` also counts as unchanged (round-3 #3); a swapped
  /// alternative selection (child UI) survives the refresh.
  @Test func test_backgroundRefresh_constitutionVersionOnlyChange_isUnchanged() async {
    let now = sofiaInstant()
    let cached = brief(cached: true, constitutionVersion: "v1")
    let regenerated = brief(cached: false, constitutionVersion: "v2") // only debug metadata differs
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(cached, .cached),
        readiness: ReadinessComponent.State(readiness: cached.readiness),
        session: SessionFeature.State(
          session: cached.session, alternatives: cached.alternatives, skipOk: cached.skipOk,
          narrative: cached.narrative.filter { $0.type == .session }, zones: nil,
          selectedAlternativeIndex: 0
        )
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in regenerated }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.pullToRefresh) {
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.zones = sampleZones()
      $0.session?.zones = sampleZones()
      $0.briefState = .ready(regenerated, .fresh)
    }
    #expect(store.state.session?.selectedAlternativeIndex == 0, "constitutionVersion-only refresh is unchanged")
  }

  // MARK: - Gate precedence + miss (AC: gate wins, miss = blocking)

  @Test func test_cacheHit_butNoCheckInToday_gateWins_checkInRequired() async {
    let now = sofiaInstant()
    let cached = brief(cached: true)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil } // no check-in → the gate precedes the peek
      $0.briefRepository.cachedDailyBrief = { cached }
    }

    await store.send(.onAppOpen)
    await store.receive(\._checkInRequired) { $0.briefState = .checkInRequired }
  }

  @Test func test_cacheMiss_runsBlockingChainUnchanged() async {
    let now = sofiaInstant()
    let fresh = brief(cached: false)
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.briefRepository.cachedDailyBrief = { nil } // MISS → the blocking chain
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in fresh }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen)
    await receiveSuccessChain(store, brief: fresh, freshness: .fresh, now: now, zones: sampleZones())
  }

  // MARK: - Pull-to-refresh (AC: no-op outside ready)

  @Test func test_pullToRefresh_outsideReady_isNoOp() async {
    let store = TestStore(initialState: TodayFeature.State(briefState: .checkInRequired)) {
      TodayFeature()
    }
    await store.send(.pullToRefresh) // no state change, no effect
  }

}
