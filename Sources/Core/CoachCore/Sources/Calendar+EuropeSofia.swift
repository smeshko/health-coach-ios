import Foundation

public extension TimeZone {
  /// The coaching server's time zone. All ISO-week / date-label math runs in this frame.
  static var europeSofia: TimeZone {
    // Force-unwrap: "Europe/Sofia" is a fixed, valid IANA identifier.
    TimeZone(identifier: "Europe/Sofia")!
  }
}

public extension Calendar {
  /// An ISO-8601 calendar pinned to Europe/Sofia.
  ///
  /// The `.iso8601` identifier already implies a Monday `firstWeekday` and
  /// `minimumDaysInFirstWeek == 4`, so ISO week-of-year math is correct without setting those
  /// fields manually.
  static var europeSofia: Calendar {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = .europeSofia
    return calendar
  }
}
