import Dependencies
import Foundation

/// An ISO-8601 week, identified by its ISO week-numbering year and week number.
///
/// Use `ISOWeek.current` / `ISOWeek.containing(_:)` so the math runs against the injected
/// `\.calendar` and `\.date` dependencies — deterministic in tests, and pinned to Europe/Sofia
/// at the composition root (see ``useEuropeSofia()``).
public struct ISOWeek: Equatable, Hashable, Sendable, Codable {
  /// The ISO week-numbering year (`yearForWeekOfYear`) — may differ from the calendar year near
  /// year boundaries (e.g. 2025-12-29 belongs to ISO year 2026).
  public let year: Int
  /// The ISO week number, 1...53.
  public let week: Int

  public init(year: Int, week: Int) {
    self.year = year
    self.week = week
  }
}

public extension ISOWeek {
  /// The ISO week containing `date`, computed with the injected `\.calendar`.
  static func containing(_ date: Date) -> ISOWeek {
    @Dependency(\.calendar) var calendar
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return ISOWeek(
      year: components.yearForWeekOfYear ?? 0,
      week: components.weekOfYear ?? 0
    )
  }

  /// The ISO week containing the injected current instant (`\.date`).
  static var current: ISOWeek {
    @Dependency(\.date) var date
    return containing(date.now)
  }
}
