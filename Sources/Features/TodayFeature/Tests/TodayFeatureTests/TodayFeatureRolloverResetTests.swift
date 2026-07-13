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

/// Phase 19.3 day-rollover reset coverage (DECISIONS D1/D2): crossing a Sofia midnight with the app
/// resident resets every per-day piece of `TodayFeature.State` at the rollover detection point
/// (`sceneBecameActive`'s rollover leg), and rollover is detectable from ALL `contentDay`-stamped states —
/// terminals (`.ready`/`.checkInRequired`/`.error`/`.syncFailed`) and in-flight (`.syncing`/`.generating`)
/// alike — not just `.ready`. `zones`/`lastSyncedAt` survive (not per-day), and background triggers never
/// move the stamp (a pull-to-refresh at 00:01 must not mask the rollover).
@MainActor
struct TodayFeatureRolloverResetTests {
  private func brief(date: Date, cached: Bool = true) -> DomainModels.DailyBrief {
    var sample = SampleData.dailyBriefGreen
    sample.date = Calendar.europeSofia.startOfDay(for: date)
    sample.cached = cached
    return sample
  }

  /// (a) Rollover from `.ready` with EVERY per-day field seeded stale: all of them reset in the
  /// `sceneBecameActive` reducer turn — including `isBackgroundRefreshing` (the rollover's
  /// `cancelInFlight` kills an in-flight background pass, so its clearing action never arrives; without
  /// the reset the "Updating…" pill sticks). `zones` + `lastSyncedAt` SURVIVE (the exhaustive closure
  /// pins the survivors by leaving them untouched). The re-orchestration lands at the new day's gate.
  @Test func test_dayRollover_fromReady_resetsAllPerDayState() async {
    let now = sofiaInstant()
    let yesterdayInstant = now.addingTimeInterval(-86400)
    let yesterday = brief(date: yesterdayInstant)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(yesterday, .cached),
        checkIn: CheckInComponent.State(
          giSymptoms: true,
          illness: true,
          kneePain: 4,
          existing: DomainModels.CheckIn(
            date: Calendar.europeSofia.startOfDay(for: yesterdayInstant),
            giSymptoms: true, kneePain: 4, illness: true
          ),
          lastSavedAt: yesterdayInstant
        ),
        readiness: ReadinessComponent.State(readiness: yesterday.readiness),
        session: SessionFeature.State(
          session: yesterday.session, alternatives: yesterday.alternatives, skipOk: yesterday.skipOk,
          narrative: yesterday.narrative.filter { $0.type == .session }, zones: sampleZones(),
          selectedIndex: 1
        ),
        zones: sampleZones(),
        lastSyncedAt: yesterdayInstant,
        isBackgroundRefreshing: true,
        lastRefreshAttemptAt: yesterdayInstant,
        restoredSelection: yesterday.alternatives[0],
        contentDay: Calendar.europeSofia.startOfDay(for: yesterdayInstant)
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil } // new day, nothing saved → the gate
    }

    await store.send(.sceneBecameActive) {
      // The per-day contract (rolloverReset): children + throttle cleared, stamp moved to today.
      $0.checkIn = CheckInComponent.State()
      $0.session = nil
      $0.restoredSelection = nil
      $0.readiness = nil
      $0.lastRefreshAttemptAt = nil
      $0.isBackgroundRefreshing = false
      $0.contentDay = sofiaToday()
    }
    await store.receive(\._checkInRequired) { $0.briefState = .checkInRequired }

    // The deliberate survivors: zones are profile-derived (19.2 refreshes them per-sync, not per-day)
    // and lastSyncedAt mirrors the sync watermark.
    #expect(store.state.zones == sampleZones())
    #expect(store.state.lastSyncedAt == yesterdayInstant)
  }

  /// (b) Rollover from a NON-`.ready` terminal stamped with yesterday's `contentDay` also
  /// re-orchestrates — the closed gap: the old detector guarded on `.ready` and returned `.none` for
  /// yesterday's `.checkInRequired`/`.error`/`.syncFailed`.
  @Test(arguments: [
    BriefViewState.checkInRequired, .error(.transientGenerationFailed), .syncFailed(.network),
  ])
  func test_dayRollover_fromTerminal_reOrchestrates(terminal: BriefViewState) async {
    let now = sofiaInstant()
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: terminal,
        contentDay: Calendar.europeSofia.startOfDay(for: now.addingTimeInterval(-86400))
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil } // new day, nothing saved → the gate re-runs
    }

    await store.send(.sceneBecameActive) { $0.contentDay = sofiaToday() }
    // Receiving `._checkInRequired` IS the re-orchestration proof; from the `.checkInRequired` terminal
    // the receive changes nothing observable (the TestStore rejects a no-op closure), so branch.
    if terminal == .checkInRequired {
      await store.receive(\._checkInRequired)
    } else {
      await store.receive(\._checkInRequired) { $0.briefState = .checkInRequired }
    }
  }

  /// (c) Rollover from an in-flight state (an overnight-suspended chain): the restart is safe because
  /// `cacheFirstOpenEffect` is `cancelInFlight` on the shared orchestration CancelID.
  @Test(arguments: [BriefViewState.syncing, .generating])
  func test_dayRollover_fromInFlight_reOrchestrates(inFlight: BriefViewState) async {
    let now = sofiaInstant()
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: inFlight,
        contentDay: Calendar.europeSofia.startOfDay(for: now.addingTimeInterval(-86400))
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.checkInRepository.current = { _ in nil }
    }

    await store.send(.sceneBecameActive) { $0.contentDay = sofiaToday() }
    await store.receive(\._checkInRequired) { $0.briefState = .checkInRequired }
  }

  /// (d) A SAME-day activation with everything seeded resets nothing — the rollover leg finds
  /// `contentDay == today` and the (fresh) staleness leg no-ops, so the send has no mutations and no
  /// effect (the exhaustive store fails on either).
  @Test func test_sameDayActivation_resetsNothing() async {
    let now = sofiaInstant()
    let sample = brief(date: now)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(sample, .cached),
        checkIn: CheckInComponent.State(existing: sampleCheckIn(), lastSavedAt: now),
        readiness: ReadinessComponent.State(readiness: sample.readiness),
        session: SessionFeature.State(
          session: sample.session, alternatives: sample.alternatives, skipOk: sample.skipOk,
          narrative: sample.narrative.filter { $0.type == .session }, zones: sampleZones(),
          selectedIndex: 1
        ),
        zones: sampleZones(),
        lastSyncedAt: now, // fresh → the staleness leg no-ops
        lastRefreshAttemptAt: now,
        restoredSelection: sample.alternatives[0],
        contentDay: sofiaToday()
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
    }

    await store.send(.sceneBecameActive) // same day + fresh → nothing reset, no effect
  }

  /// (e) Hydrate-after-rollover: post-reset, the new day's hydrate has NO stale pick to seed the
  /// carousel — `state.session?.selectedSession` and `restoredSelection` are both gone — so the
  /// preferred pick falls to the primary (index 0).
  @Test func test_dayRollover_hydrate_prefersPrimary_noStalePickSeed() async {
    let now = sofiaInstant()
    let yesterdayInstant = now.addingTimeInterval(-86400)
    let yesterday = brief(date: yesterdayInstant)
    let todayBrief = brief(date: now, cached: false)
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(yesterday, .cached),
        session: SessionFeature.State(
          session: yesterday.session, alternatives: yesterday.alternatives, skipOk: yesterday.skipOk,
          narrative: yesterday.narrative.filter { $0.type == .session }, zones: sampleZones(),
          selectedIndex: 1 // yesterday's committed pick — must NOT seed today's carousel
        ),
        zones: sampleZones(),
        restoredSelection: yesterday.alternatives[0],
        contentDay: Calendar.europeSofia.startOfDay(for: yesterdayInstant)
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() } // today's check-in already saved
      $0.sessionSelectionRepository.current = { _ in nil } // no pick persisted for today
      $0.briefRepository.cachedDailyBrief = { nil } // miss → the blocking chain
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in todayBrief }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.sceneBecameActive) {
      $0.session = nil
      $0.restoredSelection = nil
      $0.contentDay = sofiaToday()
    }
    // expectedSessionState seeds selectedIndex 0 — the new day opens on the primary.
    await receiveSuccessChain(store, brief: todayBrief, freshness: .fresh, now: now, zones: sampleZones())
    #expect(store.state.session?.selectedIndex == 0, "yesterday's pick must not seed today's carousel")
  }

  /// (e) …unless `._selectionLoaded` delivered TODAY's own persisted pick — that one still seeds the
  /// carousel after the rollover reset (the D4/D5 restore path is day-keyed and survives).
  @Test func test_dayRollover_hydrate_todaysPersistedPick_seedsCarousel() async {
    let now = sofiaInstant()
    let yesterdayInstant = now.addingTimeInterval(-86400)
    let yesterday = brief(date: yesterdayInstant)
    let todayBrief = brief(date: now, cached: false)
    let todaysPick = todayBrief.alternatives[0] // candidate 1
    let store = TestStore(
      initialState: TodayFeature.State(
        briefState: .ready(yesterday, .cached),
        session: SessionFeature.State(
          session: yesterday.session, alternatives: yesterday.alternatives, skipOk: yesterday.skipOk,
          narrative: yesterday.narrative.filter { $0.type == .session }, zones: sampleZones()
        ),
        zones: sampleZones(),
        contentDay: Calendar.europeSofia.startOfDay(for: yesterdayInstant)
      )
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.sessionSelectionRepository.current = { _ in todaysPick } // today's own persisted pick
      $0.briefRepository.cachedDailyBrief = { nil }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in todayBrief }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.sceneBecameActive) {
      $0.session = nil
      $0.contentDay = sofiaToday()
    }
    await store.receive(\._selectionLoaded, todaysPick) { $0.restoredSelection = todaysPick }
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._briefResolved) {
      $0.briefState = .ready(todayBrief, .fresh)
      $0.readiness = ReadinessComponent.State(readiness: todayBrief.readiness)
      $0.session = SessionFeature.State(
        session: todayBrief.session, alternatives: todayBrief.alternatives, skipOk: todayBrief.skipOk,
        narrative: todayBrief.narrative.filter { $0.type == .session }, zones: sampleZones(),
        selectedIndex: 1
      )
    }
    #expect(store.state.session?.selectedSession == todaysPick)
  }

  /// A background trigger must never move a stale `contentDay` stamp (DECISIONS D2, round-2 #1): a
  /// pull-to-refresh at 00:01 over a cross-midnight-hydrated brief leaves the stamp on yesterday, so the
  /// NEXT scene activation still detects the rollover instead of being permanently masked.
  @Test func test_pullToRefresh_doesNotMoveStaleContentDayStamp() async {
    let now = sofiaInstant()
    let sample = brief(date: now) // e.g. hydrated by a background pass that straddled midnight
    let staleStamp = Calendar.europeSofia.startOfDay(for: now.addingTimeInterval(-86400))
    let store = TestStore(
      initialState: TodayFeature.State(briefState: .ready(sample, .cached), contentDay: staleStamp)
    ) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in sample } // unchanged content → no swap
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.pullToRefresh) {
      // `contentDay` untouched — only the refresh status flags move.
      $0.isBackgroundRefreshing = true
      $0.lastRefreshAttemptAt = now
    }
    await store.receive(\._backgroundSyncCompleted) { $0.lastSyncedAt = now }
    await store.receive(\._backgroundRefreshResolved) {
      $0.isBackgroundRefreshing = false
      $0.zones = sampleZones()
      $0.briefState = .ready(sample, .cached)
    }
    #expect(store.state.contentDay == staleStamp, "a background pass must never mask the rollover")
  }
}
