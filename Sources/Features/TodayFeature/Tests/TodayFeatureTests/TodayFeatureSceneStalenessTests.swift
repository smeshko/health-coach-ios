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

/// Phase 12.1 scene-staleness + pull-to-refresh coverage (DECISIONS D6): on re-activation, a `contentDay`
/// rollover re-orchestrates (Phase 19.3 — the reset itself is `TodayFeatureRolloverResetTests`), a
/// same-day `.ready` brief older than `backgroundRefreshStaleness` background-refreshes quietly, and
/// otherwise nothing happens; unstamped (`contentDay == nil`) non-`.ready` states ignore activation. The
/// `max(lastSyncedAt, lastRefreshAttemptAt)` reference throttles a failed refresh so it can't re-fire on
/// every activation.
@MainActor
struct TodayFeatureSceneStalenessTests {
  private func brief(date: Date, cached: Bool = true) -> DomainModels.DailyBrief {
    var sample = SampleData.dailyBriefGreen
    sample.date = Calendar.europeSofia.startOfDay(for: date)
    sample.cached = cached
    return sample
  }

  // MARK: - Pure staleness predicate

  @Test func test_isStale_bothNil_isStale() {
    #expect(TodayFeature.isStale(
      now: sofiaInstant(), threshold: .seconds(900), lastSyncedAt: nil, lastRefreshAttemptAt: nil
    ))
  }

  @Test func test_isStale_recentSync_isFresh() {
    let now = sofiaInstant()
    #expect(!TodayFeature.isStale(
      now: now, threshold: .seconds(900),
      lastSyncedAt: now.addingTimeInterval(-60), lastRefreshAttemptAt: nil
    ))
  }

  @Test func test_isStale_oldReference_isStale() {
    let now = sofiaInstant()
    #expect(TodayFeature.isStale(
      now: now, threshold: .seconds(900),
      lastSyncedAt: now.addingTimeInterval(-901), lastRefreshAttemptAt: nil
    ))
  }

  /// The flap throttle: a recent `lastRefreshAttemptAt` (a failed-refresh marker, `lastSyncedAt` nil)
  /// keeps the activation FRESH so it can't re-fire (round-1 #3).
  @Test func test_isStale_recentAttemptOnly_isFresh() {
    let now = sofiaInstant()
    #expect(!TodayFeature.isStale(
      now: now, threshold: .seconds(900),
      lastSyncedAt: nil, lastRefreshAttemptAt: now.addingTimeInterval(-60)
    ))
  }

  // MARK: - sceneBecameActive over .ready

  @Test func test_sceneActive_sameDayFresh_noEffect() async {
    let now = sofiaInstant()
    let sample = brief(date: now)
    let store = TestStore(
      initialState: TodayFeature.State(briefState: .ready(sample, .cached), lastSyncedAt: now)
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
    }
    await store.send(.sceneBecameActive) // fresh sync → no effect, no state change
  }

  @Test func test_sceneActive_sameDayStale_backgroundRefreshes() async {
    let now = sofiaInstant()
    let sample = brief(date: now)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(sample, .cached),
        readiness: ReadinessComponent.State(readiness: sample.readiness),
        session: SessionFeature.State(
          session: sample.session, alternatives: sample.alternatives, skipOk: sample.skipOk,
          narrative: sample.narrative.filter { $0.type == .session }, zones: sampleZones()
        ),
        zones: sampleZones(),
        lastSyncedAt: now.addingTimeInterval(-1000) // older than 15 min
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in sample } // unchanged content
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
  }

  /// Day rollover (yesterday's `contentDay` stamp, Phase 19.3) → full re-orchestration hitting the
  /// check-in gate (the no-loading exemption). With no check-in for the new day → `.checkInRequired`.
  @Test func test_sceneActive_dayRollover_reOrchestrates_hitsCheckInGate() async {
    let now = sofiaInstant()
    let yesterday = brief(date: now.addingTimeInterval(-86400))
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(yesterday, .cached),
        contentDay: Calendar.europeSofia.startOfDay(for: now.addingTimeInterval(-86400))
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil } // new day, no check-in → the gate
      $0.briefRepository.cachedDailyBrief = { yesterday } // ignored — the gate precedes the peek
    }

    await store.send(.sceneBecameActive) { $0.contentDay = sofiaToday() }
    await store.receive(\._checkInRequired) { $0.briefState = .checkInRequired }
  }

  /// A cache-hit open whose background refresh FAILED (lastSyncedAt nil, lastRefreshAttemptAt set) does
  /// NOT re-refresh on an immediate re-activation; it does once the attempt timestamp passes the
  /// threshold (the flap throttle, round-1 #3).
  @Test func test_sceneActive_failedRefreshFlap_throttledUntilThresholdPasses() async {
    let openInstant = sofiaInstant()
    let sample = brief(date: openInstant)
    // State as left by a failed cache-hit open: ready, lastSyncedAt nil, lastRefreshAttemptAt = open time.
    let baseState = TodayFeature.State(
      briefState: .ready(sample, .cached),
      readiness: ReadinessComponent.State(readiness: sample.readiness),
      session: SessionFeature.State(
        session: sample.session, alternatives: sample.alternatives, skipOk: sample.skipOk,
        narrative: sample.narrative.filter { $0.type == .session }, zones: sampleZones()
      ),
      zones: sampleZones(),
      lastSyncedAt: nil,
      isBackgroundRefreshing: false,
      lastRefreshAttemptAt: openInstant
    )

    // Re-activate 1 minute later → still fresh by the attempt timestamp → no effect.
    let soon = openInstant.addingTimeInterval(60)
    let store1 = TestStore(initialState: baseState) { TodayFeature() } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(soon)
    }
    await store1.send(.sceneBecameActive) // throttled — no effect

    // Re-activate 16 minutes later → the attempt timestamp is now stale → background refresh fires.
    let later = openInstant.addingTimeInterval(16 * 60)
    let store2 = TestStore(initialState: baseState) { TodayFeature() } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(later)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in sample }
      $0.profileRepository.zones = { sampleZones() }
    }
    await store2.send(.sceneBecameActive) {
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = later
    }
    await store2.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = later }
    await store2.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.briefState = .ready(sample, .cached)
    }
  }

  @Test func test_sceneActive_nonReady_isNoOp() async {
    for state in [BriefViewState.syncing, .generating, .checkInRequired, .syncFailed(.network)] {
      let store = TestStore(initialState: TodayFeature.State(briefState: state)) {
        TodayFeature()
      } withDependencies: {
        $0.calendar = .europeSofia
        $0.date = .constant(sofiaInstant())
      }
      await store.send(.sceneBecameActive) // no-op: an unstamped (contentDay nil) non-ready state
    }
  }
}
