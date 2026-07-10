import BriefRepository
import Clocks
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import SampleData
import SyncRepository
import Testing

@testable import TodayFeature

/// Phase 12.1 zone-merge + quiet-degrade coverage (DECISIONS D3/D6): a background refresh always merges a
/// non-nil zones into both `state.zones` and the live session child (preserving its UI state), a nil fetch
/// preserves previously held zones, and a background failure (sync-failed or sync-ok/brief-failed) stays
/// `.ready` with its truthful sync status — never an error or loading state.
@MainActor
struct TodayFeatureBackgroundDegradeTests {
  private func brief(cached: Bool = true) -> DomainModels.DailyBrief {
    var sample = SampleData.dailyBriefGreen
    sample.cached = cached
    return sample
  }

  private func expectedReadiness(_ sample: DomainModels.DailyBrief) -> ReadinessComponent.State {
    ReadinessComponent.State(readiness: sample.readiness)
  }

  private func session(_ sample: DomainModels.DailyBrief, zones: DomainModels.Zones?) -> SessionFeature.State {
    SessionFeature.State(
      session: sample.session, alternatives: sample.alternatives, skipOk: sample.skipOk,
      narrative: sample.narrative.filter { $0.type == .session }, zones: zones
    )
  }

  /// A `nil` zones fetch on an unchanged refresh preserves previously held zones (round-2 #1).
  @Test func test_backgroundRefresh_nilZones_preservesPreviousZones() async {
    let now = sofiaInstant()
    let cached = brief(cached: true)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(cached, .cached),
        readiness: expectedReadiness(cached),
        session: session(cached, zones: sampleZones()),
        zones: sampleZones()
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in cached }
      $0.profileRepository.zones = { throw BriefError.serverError } // fetch fails → nil
    }

    await store.send(.pullToRefresh) {
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.briefState = .ready(cached, .cached)
    }
    #expect(store.state.zones == sampleZones(), "a nil zones fetch keeps the previously held zones")
  }

  /// The success path re-reads `zones()` AFTER the sync (Phase 19.2 review round-1 #1): a sync that
  /// advances the watermark `serverTime` makes the cached profile stale, so the post-sync read is the one
  /// that picks up recomputed constants — THIS pass must deliver them, not the next one. The stub flips on
  /// sync exactly like the live repo: pre-sync reads serve the old cached zones, post-sync the recomputed.
  @Test func test_backgroundRefresh_syncOk_deliversPostSyncRecomputedZones() async {
    let now = sofiaInstant()
    let cached = brief(cached: true)
    let recomputed = DomainModels.Zones(
      z1: DomainModels.ZoneRange(low: 100, high: 119),
      z2: DomainModels.ZoneRange(low: 119, high: 138),
      z3: DomainModels.ZoneRange(low: 138, high: 157),
      z4: DomainModels.ZoneRange(low: 157, high: 176),
      z5: DomainModels.ZoneRange(low: 176, high: 195)
    )
    let synced = LockIsolated(false)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(cached, .cached),
        readiness: expectedReadiness(cached),
        session: session(cached, zones: sampleZones()),
        zones: sampleZones()
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = {
        synced.setValue(true)
        return sampleSyncResult()
      }
      $0.briefRepository.dailyBrief = { _ in cached }
      $0.profileRepository.zones = { synced.value ? recomputed : sampleZones() }
    }

    await store.send(.pullToRefresh) {
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.zones = recomputed
      $0.session?.zones = recomputed
    }
    #expect(store.state.zones == recomputed, "the pass delivers the post-sync (recomputed) zones")
  }

  /// A cache-hit open + cached zones + a FAILING `sync()` → zones still merge into parent + session child
  /// via `._backgroundRefreshFailed(zones)` (round-3 #2), and the state stays `.ready(cached, .cached)`.
  @Test func test_backgroundRefresh_syncFails_zonesStillMerge_quietDegrade() async {
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
      $0.syncRepository.sync = { throw SyncError.network }
      $0.briefRepository.dailyBrief = { _ in cached }
      $0.profileRepository.zones = { sampleZones() } // cached zones survive the failing sync
    }

    await store.send(.onAppOpen) { $0.contentDay = sofiaToday() }
    await store.receive(\._cachedBriefLoaded) {
      $0.briefState = .ready(cached, .cached)
      $0.readiness = expectedReadiness(cached)
      $0.session = session(cached, zones: nil)
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    // sync() threw → no `._backgroundSyncCompleted`; the failed pass still merges the already-fetched zones.
    await store.receive(\._backgroundRefreshFailed) {
      $0.isBackgroundRefreshing = false
      $0.zones = sampleZones()
      $0.session?.zones = sampleZones()
    }
    #expect(store.state.briefState == .ready(cached, .cached), "sync failure degrades quietly")
    #expect(store.state.lastSyncedAt == nil, "no successful sync → pill stays hidden")
  }

  /// Background `sync()` SUCCESS then `dailyBrief(true)` FAILURE → `lastSyncedAt` recorded by
  /// `._backgroundSyncCompleted` (pill truthfully "Synced X ago"), state stays `.ready(cached, .cached)`,
  /// flag cleared (round-2 #3).
  @Test func test_backgroundRefresh_syncOk_briefFails_recordsSyncedAt_quietDegrade() async {
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
      $0.briefRepository.dailyBrief = { _ in throw BriefError.serverError }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen) { $0.contentDay = sofiaToday() }
    await store.receive(\._cachedBriefLoaded) {
      $0.briefState = .ready(cached, .cached)
      $0.readiness = expectedReadiness(cached)
      $0.session = session(cached, zones: nil)
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshFailed) {
      $0.isBackgroundRefreshing = false
      $0.zones = sampleZones()
      $0.session?.zones = sampleZones()
    }
    #expect(store.state.lastSyncedAt == now, "sync succeeded → pill shows Synced X ago even though brief failed")
    #expect(store.state.briefState == .ready(cached, .cached))
  }

  /// Sync SUCCESS + brief FAILURE still delivers the POST-sync zones (Phase 19.2 review round-2 #1):
  /// the successful sync advanced the watermark and recomputed constants, so the quiet-degrade path must
  /// merge the recomputed zones, not the pre-sync cached ones.
  @Test func test_backgroundRefresh_syncOk_briefFails_deliversPostSyncRecomputedZones() async {
    let now = sofiaInstant()
    let cached = brief(cached: true)
    let recomputed = DomainModels.Zones(
      z1: DomainModels.ZoneRange(low: 100, high: 119),
      z2: DomainModels.ZoneRange(low: 119, high: 138),
      z3: DomainModels.ZoneRange(low: 138, high: 157),
      z4: DomainModels.ZoneRange(low: 157, high: 176),
      z5: DomainModels.ZoneRange(low: 176, high: 195)
    )
    let synced = LockIsolated(false)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(cached, .cached),
        readiness: expectedReadiness(cached),
        session: session(cached, zones: sampleZones()),
        zones: sampleZones()
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = {
        synced.setValue(true)
        return sampleSyncResult()
      }
      $0.briefRepository.dailyBrief = { _ in throw BriefError.serverError }
      $0.profileRepository.zones = { synced.value ? recomputed : sampleZones() }
    }

    await store.send(.pullToRefresh) {
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshFailed) {
      $0.isBackgroundRefreshing = false
      $0.zones = recomputed
      $0.session?.zones = recomputed
    }
    #expect(store.state.zones == recomputed, "the failed-brief path still delivers the post-sync zones")
  }
}
