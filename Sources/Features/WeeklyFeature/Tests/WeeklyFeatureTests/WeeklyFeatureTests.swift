import CoachCore
import ComposableArchitecture
import Foundation
import Testing

@testable import WeeklyFeature

/// The target/harness smoke test + the new-ISO-week detection (TASK-002). The fetch/orchestration
/// (TASK-003), rhythm + toggles (TASK-004) cases grow this suite.
@MainActor
struct WeeklyFeatureTests {
  @Test func test_initialState_isIdle() {
    let state = WeeklyFeature.State()
    #expect(state.weeklyState == .idle)
  }

  @Test func test_noOpAction_doesNotMutate() async {
    let store = TestStore(initialState: WeeklyFeature.State()) {
      WeeklyFeature()
    }
    // The shell is a no-op until TASK-003's fetch effect — `task` produces no state change, no effect.
    await store.send(.task)
  }

  // MARK: - New-ISO-week detection (TASK-002)

  @Test func test_isoWeekKey_zeroPadsAndHandlesYearBoundary() {
    #expect(isoWeekKey(ISOWeek(year: 2026, week: 3)) == "2026-W03")
    // The ISO year-numbering boundary: 2026 is a 53-week ISO year; its W53 and the next ISO year's W01.
    #expect(isoWeekKey(ISOWeek(year: 2026, week: 52)) == "2026-W52")
    #expect(isoWeekKey(ISOWeek(year: 2026, week: 53)) == "2026-W53")
    #expect(isoWeekKey(ISOWeek(year: 2027, week: 1)) == "2027-W01")
  }

  @Test func test_currentISOWeekKey_flipsAcrossSofiaWeeks() {
    // Two instants on different Sofia ISO weeks → two distinct keys (deterministic).
    let w24 = withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.sofiaMidday(2026, 6, 8)) // Monday of 2026-W24
    } operation: {
      WeeklyFeature().currentISOWeekKey
    }
    let w25 = withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.sofiaMidday(2026, 6, 15)) // Monday of 2026-W25
    } operation: {
      WeeklyFeature().currentISOWeekKey
    }
    #expect(w24 == "2026-W24")
    #expect(w25 == "2026-W25")
    #expect(w24 != w25)
  }

  @Test func test_isNewWeek_predicate() {
    withDependencies {
      // A fresh in-memory appStorage suite so the watermark never leaks between tests / real UserDefaults.
      $0.defaultAppStorage = UserDefaults(suiteName: "weekly-isnewweek-\(UUID().uuidString)")!
      $0.useEuropeSofia()
      $0.date = .constant(Self.sofiaMidday(2026, 6, 8))
    } operation: {
      let feature = WeeklyFeature()
      var state = WeeklyFeature.State()
      #expect(state.lastSeenISOWeek == nil)
      #expect(feature.isNewWeek(state) == true) // nil watermark → new
      state.$lastSeenISOWeek.withLock { $0 = "2025-W01" }
      #expect(feature.isNewWeek(state) == true) // differs → new
      state.$lastSeenISOWeek.withLock { $0 = feature.currentISOWeekKey }
      #expect(feature.isNewWeek(state) == false) // matches → not new
    }
  }

  /// A Europe/Sofia midday instant, host-timezone-independent (mirrors WeeklyCachePolicyTests' helper).
  private static func sofiaMidday(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
  }
}
