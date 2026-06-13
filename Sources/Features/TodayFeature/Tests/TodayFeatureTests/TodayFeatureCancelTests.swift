import BriefRepository
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import SampleData
import SyncRepository
import Testing

@testable import TodayFeature

/// Phase 12.1 Cancel + race coverage (DECISIONS D4): the (now-rare) blocking sync/generate screen's quiet
/// Cancel cancels the orchestration and falls back to the cached brief when one exists (hydrate-only, no
/// background refresh), else `.syncFailed(.transient)` + Retry. The fallbacks are state-gated so a brief
/// that landed just before the cancel is never stomped (the late-resume / already-ready races).
@MainActor
struct TodayFeatureCancelTests {
  private func brief(cached: Bool = true, skipOk: Bool? = nil) -> DomainModels.DailyBrief {
    var sample = SampleData.dailyBriefGreen
    sample.cached = cached
    if let skipOk { sample.skipOk = skipOk }
    return sample
  }

  private func expectedSession(_ sample: DomainModels.DailyBrief) -> SessionFeature.State {
    SessionFeature.State(
      session: sample.session, alternatives: sample.alternatives, skipOk: sample.skipOk,
      narrative: sample.narrative.filter { $0.type == .session }, zones: nil
    )
  }

  @Test func test_cancelDuringSyncing_withCachedBrief_fallsBackToCached_noBackgroundRefresh() async {
    let now = sofiaInstant()
    let cached = brief(cached: true)
    let store = TestStore(initialState: TodayFeature.State(briefState: .syncing)) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.briefRepository.cachedDailyBrief = { cached }
    }

    await store.send(.cancelSyncTapped)
    await store.receive(\._cachedBriefLoaded) {
      // Hydrate-only — no background refresh started, no Updating… pill.
      $0.briefState = .ready(cached, .cached)
      $0.readiness = ReadinessComponent.State(readiness: cached.readiness)
      $0.session = self.expectedSession(cached)
    }
    #expect(store.state.isBackgroundRefreshing == false, "cancel must not start a background refresh")
  }

  @Test func test_cancelDuringSyncing_noCache_landsSyncFailedTransient() async {
    let store = TestStore(initialState: TodayFeature.State(briefState: .syncing)) {
      TodayFeature()
    } withDependencies: {
      $0.briefRepository.cachedDailyBrief = { nil }
    }

    await store.send(.cancelSyncTapped)
    await store.receive(\._syncFailed) { $0.briefState = .syncFailed(.transient) }
  }

  /// Cancel racing an already-landed `.ready(brief, .fresh)` → the fallback is discarded (the public
  /// cancel action is gated to syncing/generating), the fresh brief stays (round-2 #2).
  @Test func test_cancelFallback_discardedWhenAlreadyReady() async {
    let fresh = brief(cached: false)
    let cached = brief(cached: true, skipOk: !fresh.skipOk)
    let store = TestStore(initialState: TodayFeature.State(briefState: .ready(fresh, .fresh))) {
      TodayFeature()
    } withDependencies: {
      $0.briefRepository.cachedDailyBrief = { cached }
    }

    await store.send(.cancelSyncTapped) // .ready → guard returns .none, no peek, no state change
    #expect(store.state.briefState == .ready(fresh, .fresh), "a landed brief is not stomped by cancel")
  }

  /// Even if a stale `._cachedBriefLoaded(_, startBackgroundRefresh: false)` is delivered after the brief
  /// already landed, the reducer's state-gate discards it (the late-resume race, round-2 #2).
  @Test func test_lateCachedBriefLoaded_overReady_isDiscarded() async {
    let fresh = brief(cached: false)
    let stale = brief(cached: true, skipOk: !fresh.skipOk)
    let store = TestStore(initialState: TodayFeature.State(briefState: .ready(fresh, .fresh))) {
      TodayFeature()
    }
    await store.send(._cachedBriefLoaded(stale, startBackgroundRefresh: false))
    #expect(store.state.briefState == .ready(fresh, .fresh))
  }

  /// `._syncFailed` over `.ready` (a late cancel-path send) is discarded (state-gated).
  @Test func test_lateSyncFailed_overReady_isDiscarded() async {
    let fresh = brief(cached: false)
    let store = TestStore(initialState: TodayFeature.State(briefState: .ready(fresh, .fresh))) {
      TodayFeature()
    }
    await store.send(._syncFailed(.transient)) // discarded — not syncing/generating
    #expect(store.state.briefState == .ready(fresh, .fresh))
  }
}
