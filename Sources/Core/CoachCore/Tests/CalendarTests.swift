import Dependencies
import Foundation
import Testing

@testable import CoachCore

struct CalendarTests {
  /// Build a `Date` for a wall-clock day in Europe/Sofia (noon, to avoid DST/midnight edges).
  private func sofiaDate(year: Int, month: Int, day: Int) -> Date {
    sofiaDate(year: year, month: month, day: day, hour: 12)
  }

  /// Build a `Date` for a wall-clock instant in Europe/Sofia.
  private func sofiaDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return Calendar.europeSofia.date(from: components)!
  }

  @Test func testISOWeekAtYearBoundaryResolvesInEuropeSofia() {
    // 2025-12-29 is a Monday; its ISO week (Mon 2025-12-29 … Sun 2026-01-04) contains 2026-01-04,
    // so it is ISO week 1 of 2026 — the year-numbering rolls over before the calendar year.
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2025, month: 12, day: 29))
    } operation: {
      #expect(ISOWeek.current == ISOWeek(year: 2026, week: 1))
    }
  }

  @Test func testISOWeekRollsOverToWeekTwo() {
    // 2026-01-05 is the next Monday → ISO week 2 of 2026.
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(sofiaDate(year: 2026, month: 1, day: 5))
    } operation: {
      #expect(ISOWeek.current == ISOWeek(year: 2026, week: 2))
    }
  }

  @Test func testContainingComputesWeekForArbitraryDate() {
    // 2026-06-08 is a Monday in ISO week 24 of 2026.
    withDependencies {
      $0.calendar = .europeSofia
    } operation: {
      #expect(ISOWeek.containing(sofiaDate(year: 2026, month: 6, day: 8)) == ISOWeek(year: 2026, week: 24))
    }
  }

  /// A fixed instant constructed in UTC, *independent* of `Calendar.europeSofia`, so that the only
  /// thing deciding its ISO week is the injected read calendar's time zone.
  private func utcInstant(year: Int, month: Int, day: Int, hour: Int) -> Date {
    var utc = Calendar(identifier: .iso8601)
    utc.timeZone = TimeZone(identifier: "UTC")!
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return utc.date(from: components)!
  }

  @Test func testTimeZoneIsLoadBearingAtMidnightBoundary() {
    // 2026-01-04 22:00 UTC is the same instant as 2026-01-05 00:00 in Europe/Sofia (UTC+2). The
    // instant is built from a UTC calendar, NOT from Calendar.europeSofia, so only the injected read
    // calendar's time zone determines the result:
    //   - read in Europe/Sofia → Monday 2026-01-05 → ISO week 2  (asserted)
    //   - read in UTC          → Sunday 2026-01-04 → ISO week 1
    // So this fails if Calendar.europeSofia's time zone ever regresses away from Europe/Sofia — the
    // .iso8601 identifier alone is not enough to make it pass.
    let instant = utcInstant(year: 2026, month: 1, day: 4, hour: 22)
    withDependencies {
      $0.calendar = .europeSofia
      $0.date = .constant(instant)
    } operation: {
      #expect(ISOWeek.current == ISOWeek(year: 2026, week: 2))
    }
  }

  @Test func testUseEuropeSofiaPinsCalendarAndTimeZone() {
    withDependencies {
      $0.useEuropeSofia()
    } operation: {
      @Dependency(\.calendar) var calendar
      @Dependency(\.timeZone) var timeZone
      #expect(calendar.timeZone.identifier == "Europe/Sofia")
      #expect(calendar.identifier == .iso8601)
      #expect(timeZone.identifier == "Europe/Sofia")
    }
  }
}
