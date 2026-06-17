import Dependencies
import Foundation
import Testing

@testable import CoachCore

struct StrengthTestDueTests {
  /// Build a `Date` for noon on a wall-clock day in Europe/Sofia (avoids DST/midnight edges).
  private func sofiaDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar.europeSofia.date(from: components)!
  }

  @Test func testNoLastTestIsDue() {
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2026, month: 6, day: 10))
    } operation: {
      #expect(isStrengthTestDue(lastTestDate: nil))
    }
  }

  @Test func testTestEarlierThisIsoWeekIsNotDue() {
    // now: 2026-06-10 (Wed, ISO week 24 of 2026); last: 2026-06-08 (Mon, same ISO week) → not due.
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2026, month: 6, day: 10))
    } operation: {
      #expect(!isStrengthTestDue(lastTestDate: sofiaDate(year: 2026, month: 6, day: 8)))
    }
  }

  @Test func testTestInPriorIsoWeekIsDue() {
    // now: 2026-06-10 (ISO week 24); last: 2026-06-01 (Mon, ISO week 23) → due.
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2026, month: 6, day: 10))
    } operation: {
      #expect(isStrengthTestDue(lastTestDate: sofiaDate(year: 2026, month: 6, day: 1)))
    }
  }

  @Test func testTestInPriorIsoWeekAcrossYearBoundaryIsDue() {
    // now: 2026-01-05 (Mon, ISO week 2 of 2026); last: 2025-12-22 (Mon, ISO week 52 of 2025) — a
    // different `yearForWeekOfYear` → due. (ISOWeek owns the year-boundary math; this only pins the
    // due predicate across that boundary.)
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2026, month: 1, day: 5))
    } operation: {
      #expect(isStrengthTestDue(lastTestDate: sofiaDate(year: 2025, month: 12, day: 22)))
    }
  }
}
