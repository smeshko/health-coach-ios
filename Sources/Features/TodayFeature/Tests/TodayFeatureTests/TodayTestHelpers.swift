import ComposableArchitecture
import CoachCore
import DomainModels
import Foundation
import SampleData
import SyncRepository
import Testing

@testable import TodayFeature

// Shared test helpers for the TodayFeature orchestration + refresh suites. Free functions / actors (not
// nested in a test struct) so the `@Sendable` dependency-stub closures capture only Sendable values,
// never a test `self`, under Swift 6 strict concurrency.

/// Counts `BriefRepository.dailyBrief` invocations so a test can assert exactly 0 (blocked) / 1 (ran).
actor BriefCallCounter {
  private(set) var count = 0
  func increment() { count += 1 }
}

/// Records the `refresh` flag each `dailyBrief` call received — so the save-triggered tests can assert
/// the save path passes `refresh: true` (4.2 has no distinct `refresh()` method).
actor RefreshFlagRecorder {
  private(set) var flags: [Bool] = []
  func record(_ refresh: Bool) { flags.append(refresh) }
}

/// A saved check-in for the `sofiaInstant()` day — unlocks the orchestration's check-in gate (no
/// check-in today → the chain stops at `.checkInRequired` and never syncs).
func sampleCheckIn() -> DomainModels.CheckIn {
  DomainModels.CheckIn(
    date: Calendar.europeSofia.startOfDay(for: sofiaInstant()),
    giSymptoms: false,
    kneePain: 0,
    illness: false
  )
}

/// A wall-clock instant in Europe/Sofia (the pinned frame).
func sofiaInstant() -> Date {
  var components = DateComponents()
  components.year = 2026
  components.month = 6
  components.day = 10
  components.hour = 9
  return Calendar.europeSofia.date(from: components)!
}

/// The default green sample brief with `cached` forced to a known value.
func sampleBrief(cached: Bool) -> DomainModels.DailyBrief {
  var brief = SampleData.dailyBriefGreen
  brief.cached = cached
  return brief
}

/// A deterministic five-zone bpm map for the orchestration's `profileRepository.zones()` stub, so the
/// session child (Phase 8.4) hydrates with a known `zones` the exhaustive `TestStore` can assert on.
func sampleZones() -> DomainModels.Zones {
  DomainModels.Zones(
    z1: DomainModels.ZoneRange(low: 95, high: 114),
    z2: DomainModels.ZoneRange(low: 114, high: 133),
    z3: DomainModels.ZoneRange(low: 133, high: 152),
    z4: DomainModels.ZoneRange(low: 152, high: 171),
    z5: DomainModels.ZoneRange(low: 171, high: 190)
  )
}

/// The daily-session child state the parent hydrates on an untripped `._briefResolved` (Phase 8.4) — the
/// brief's session + alternatives + `skipOk` + the `.session` narrative slice + the fetched zones. Mirrors
/// `TodayFeature`'s hydration so the exhaustive `TestStore` asserts the child appears under `ready`.
func expectedSessionState(_ brief: DomainModels.DailyBrief, zones: DomainModels.Zones) -> SessionFeature.State {
  SessionFeature.State(
    session: brief.session,
    alternatives: brief.alternatives,
    skipOk: brief.skipOk,
    narrative: brief.narrative.filter { $0.type == .session },
    zones: zones
  )
}

/// The success-chain `receive` walk shared by every orchestration that reaches `.ready` on an immediate
/// clock — `_syncStarted` → `_generating` (records `lastSyncedAt`) → `_briefResolved` (hydrates the
/// `.ready` state, the readiness child, `zones`, and the untripped session child). Extracted so the
/// cache-hit / retry / save / log variants share one walk instead of copy-pasting it ~8× (Phase 11.4 D4);
/// the only per-test knobs are the resolved `brief`, its `freshness`, the `now` instant, and the `zones`.
@MainActor
func receiveSuccessChain(
  _ store: TestStoreOf<TodayFeature>,
  brief: DomainModels.DailyBrief,
  freshness: Freshness,
  now: Date,
  zones: DomainModels.Zones
) async {
  await store.receive(\._syncStarted) { $0.briefState = .syncing }
  await store.receive(\._generating) {
    $0.lastSyncedAt = now
    $0.briefState = .generating
  }
  await store.receive(\._briefResolved) {
    $0.briefState = .ready(brief, freshness)
    $0.zones = zones
    $0.readiness = ReadinessComponent.State(readiness: brief.readiness)
    $0.session = expectedSessionState(brief, zones: zones)
  }
}

/// A canned successful, zero-upsert sync result.
func sampleSyncResult() -> SyncResult {
  SyncResult(
    recordsUpserted: 0,
    recordsDuplicate: 0,
    workoutsUpserted: 0,
    activityDaysUpserted: 0,
    checkinSaved: false,
    strengthTestSaved: false,
    serverTime: Date(timeIntervalSince1970: 0)
  )
}
