import Dependencies
import Foundation
import XCTest

@testable import CoachCore

final class CalendarTests: XCTestCase {
  /// Build a `Date` for a wall-clock day in Europe/Sofia (noon, to avoid DST/midnight edges).
  private func sofiaDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar.europeSofia.date(from: components)!
  }

  func testISOWeekAtYearBoundaryResolvesInEuropeSofia() {
    // 2025-12-29 is a Monday; its ISO week (Mon 2025-12-29 … Sun 2026-01-04) contains 2026-01-04,
    // so it is ISO week 1 of 2026 — the year-numbering rolls over before the calendar year.
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2025, month: 12, day: 29))
    } operation: {
      XCTAssertEqual(ISOWeek.current, ISOWeek(year: 2026, week: 1))
    }
  }

  func testISOWeekRollsOverToWeekTwo() {
    // 2026-01-05 is the next Monday → ISO week 2 of 2026.
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2026, month: 1, day: 5))
    } operation: {
      XCTAssertEqual(ISOWeek.current, ISOWeek(year: 2026, week: 2))
    }
  }

  func testContainingComputesWeekForArbitraryDate() {
    // 2026-06-08 is a Monday in ISO week 24 of 2026.
    withDependencies {
      $0.calendar = .europeSofia
    } operation: {
      XCTAssertEqual(ISOWeek.containing(sofiaDate(year: 2026, month: 6, day: 8)), ISOWeek(year: 2026, week: 24))
    }
  }

  func testUseEuropeSofiaPinsCalendarAndTimeZone() {
    withDependencies {
      $0.useEuropeSofia()
    } operation: {
      @Dependency(\.calendar) var calendar
      @Dependency(\.timeZone) var timeZone
      XCTAssertEqual(calendar.timeZone.identifier, "Europe/Sofia")
      XCTAssertEqual(calendar.identifier, .iso8601)
      XCTAssertEqual(timeZone.identifier, "Europe/Sofia")
    }
  }
}
