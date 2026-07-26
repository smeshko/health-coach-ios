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

/// Pins which orchestration triggers may force an LLM regeneration (`dailyBrief(refresh: true)`) after
/// the 2026-07-26 incident: a hardcoded `refresh: true` in the open path regenerated — and could flip —
/// the brief on every app open. The contract: the cache-hit open pass and the scene-staleness pass send
/// `refresh: false`; only pull-to-refresh (here) and the check-in save (`TodayFeatureSaveTests`) send
/// `refresh: true`.
@MainActor
struct TodayFeatureRefreshFlagTests {
  /// The cache-hit open's quiet background pass must NOT force regeneration.
  @Test func test_cacheHitOpen_backgroundPass_sendsRefreshFalse() async {
    let now = sofiaInstant()
    let cached = sampleBrief(cached: true)
    let recorder = RefreshFlagRecorder()
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.briefRepository.cachedDailyBrief = { cached }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { refresh in
        await recorder.record(refresh)
        return cached // unchanged content → no swap
      }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen) { $0.contentDay = sofiaToday() }
    await store.receive(\._cachedBriefLoaded) {
      $0.briefState = .ready(cached, .cached)
      $0.readiness = ReadinessComponent.State(readiness: cached.readiness)
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
      $0.session?.zones = sampleZones()
      $0.briefState = .ready(cached, .cached)
    }
    let flags = await recorder.flags
    #expect(flags == [false], "the open pass must not force regeneration")
  }

  /// Pull-to-refresh is explicit intent — the one background trigger that forces regeneration.
  @Test func test_pullToRefresh_sendsRefreshTrue() async {
    let now = sofiaInstant()
    let sample = sampleBrief(cached: true)
    let recorder = RefreshFlagRecorder()
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(sample, .cached),
        readiness: ReadinessComponent.State(readiness: sample.readiness),
        session: SessionFeature.State(
          session: sample.session, alternatives: sample.alternatives, skipOk: sample.skipOk,
          narrative: sample.narrative.filter { $0.type == .session }, zones: sampleZones()
        ),
        zones: sampleZones(),
        // A fresh sync just happened — pull-to-refresh has no staleness gate, so it must regenerate
        // anyway. Seeded *behind* the constant clock so `_backgroundSyncCompleted`'s watermark bump is
        // an observable state change (a `lastSyncedAt: now` seed makes the receive assertion vacuous).
        lastSyncedAt: now.addingTimeInterval(-60)
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { refresh in
        await recorder.record(refresh)
        return sample // unchanged content
      }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.pullToRefresh) {
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.briefState = .ready(sample, .cached)
    }
    let flags = await recorder.flags
    #expect(flags == [true], "pull-to-refresh forces regeneration")
  }

  /// A mere re-foreground past the staleness threshold syncs + reconciles but must NOT force regeneration.
  @Test func test_sceneStaleness_backgroundPass_sendsRefreshFalse() async {
    let now = sofiaInstant()
    let sample = sampleBrief(cached: true)
    let recorder = RefreshFlagRecorder()
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(sample, .cached),
        readiness: ReadinessComponent.State(readiness: sample.readiness),
        session: SessionFeature.State(
          session: sample.session, alternatives: sample.alternatives, skipOk: sample.skipOk,
          narrative: sample.narrative.filter { $0.type == .session }, zones: sampleZones()
        ),
        zones: sampleZones(),
        lastSyncedAt: now.addingTimeInterval(-1000) // older than the 15-min threshold
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { refresh in
        await recorder.record(refresh)
        return sample // unchanged content
      }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.sceneBecameActive) {
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.briefState = .ready(sample, .cached)
    }
    let flags = await recorder.flags
    #expect(flags == [false], "a re-foreground must not force regeneration")
  }
}
