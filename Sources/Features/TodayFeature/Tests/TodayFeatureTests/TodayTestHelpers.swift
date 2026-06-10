import CoachCore
import DomainModels
import Foundation
import SampleData
import SyncRepository

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
