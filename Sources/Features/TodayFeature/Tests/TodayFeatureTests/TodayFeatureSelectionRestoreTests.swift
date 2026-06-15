import Clocks
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import TodayFeature

/// Coverage (ARCHITECTURE D18) for the persisted daily-pick wiring (TASK-005, DECISIONS D4/D5): app-open
/// **restore** seeds the carousel on the stored block (matched by value), **write-through** persists a
/// committed selection for today, and a **stale** stored block (no longer among the candidates) falls back
/// to the primary. The pure feature only emits `selectionChanged`; the parent owns the repository.
@MainActor
struct TodayFeatureSelectionRestoreTests {
  /// Records the `(block, date)` pairs the write-through saves (mirrors the save-spy actors elsewhere).
  private actor SelectionSaveRecorder {
    private(set) var saved: [(block: SessionBlock, date: Date)] = []
    func record(_ block: SessionBlock, _ date: Date) { saved.append((block, date)) }
  }

  /// A cache-first app open with a persisted pick restores it BEFORE the brief renders, so the carousel
  /// opens on the stored block (candidate 1), not the primary — and the quiet background refresh keeps it.
  @Test func test_onAppOpen_restoresPersistedPick_carouselOpensOnIt() async {
    let now = sofiaInstant()
    let cached = sampleBrief(cached: true)
    let pick = cached.alternatives[0] // candidate 1
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.sessionSelectionRepository.current = { _ in pick }
      $0.briefRepository.cachedDailyBrief = { cached }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in cached } // unchanged content → no swap
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen)
    // The persisted pick is restored first (before any hydration).
    await store.receive(\._selectionLoaded, pick) { $0.restoredSelection = pick }
    // The cache render seeds the carousel on the restored pick (selectedIndex 1), not the primary.
    await store.receive(\._cachedBriefLoaded) {
      $0.briefState = .ready(cached, .cached)
      $0.readiness = ReadinessComponent.State(readiness: cached.readiness)
      $0.session = SessionFeature.State(
        session: cached.session, alternatives: cached.alternatives, skipOk: cached.skipOk,
        narrative: cached.narrative.filter { $0.type == .session }, zones: nil, selectedIndex: 1
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
    // The pick survived the open + background refresh.
    #expect(store.state.session?.selectedIndex == 1)
    #expect(store.state.session?.selectedSession == pick)
  }

  /// Committing a card writes the chosen block through to the repository, keyed by today's Sofia day.
  @Test func test_selectionChanged_persistsPickForToday() async {
    let now = sofiaInstant()
    let brief = sampleBrief(cached: true)
    let recorder = SelectionSaveRecorder()
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(brief, .cached),
        session: expectedSessionState(brief, zones: sampleZones())
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.sessionSelectionRepository.save = { block, date in await recorder.record(block, date) }
    }

    await store.send(.session(.cardSelected(index: 1))) { $0.session?.selectedIndex = 1 }
    await store.receive(\.session.delegate, .selectionChanged(brief.alternatives[0]))
    await store.finish() // let the fire-and-forget save complete

    let saved = await recorder.saved
    #expect(saved.count == 1, "committing a card persists exactly one pick")
    #expect(saved.first?.block == brief.alternatives[0])
    #expect(saved.first?.date == Calendar.europeSofia.startOfDay(for: now), "keyed by today's Sofia day")
  }

  /// A restored pick that is no longer among the brief's candidates (a refreshed brief changed the
  /// alternatives) falls back to the primary — `selectedIndex` 0, no crash, no stale display.
  @Test func test_restoredPick_absentFromBrief_fallsBackToPrimary() async {
    let brief = sampleBrief(cached: false)
    // A block that is NOT among the brief's candidates (a distinct card + zone).
    let stranger = SessionBlock(
      card: .vo2, intensity: .quality, zoneTarget: .z5, durationMinLow: 20, durationMinHigh: 25
    )
    let store = TestStore(initialState: TodayFeature.State()) { TodayFeature() }

    await store.send(._selectionLoaded(stranger)) { $0.restoredSelection = stranger }
    await store.send(._briefResolved(brief, .fresh, sampleZones())) {
      $0.briefState = .ready(brief, .fresh)
      $0.zones = sampleZones()
      $0.readiness = ReadinessComponent.State(readiness: brief.readiness)
      // expectedSessionState seeds selectedIndex 0 — the stale stranger degrades to the primary.
      $0.session = expectedSessionState(brief, zones: sampleZones())
    }
    #expect(store.state.session?.selectedIndex == 0)
  }
}
