import CoachCore
import Foundation

/// Shared, deterministic date formatters for the wire contract.
///
/// The wire carries two distinct shapes (ARCHITECTURE §5, `openapi.yaml` `format` tags):
/// - `format: date` — a calendar date `yyyy-MM-dd` (handled by ``WireCalendarDate``).
/// - `format: date-time` — an ISO-8601 instant rendered in **Europe/Sofia** local time with a
///   DST-aware `±HH:MM` offset and optional fractional seconds.
///
/// All formatters pin `Locale(identifier: "en_US_POSIX")` + the Europe/Sofia time zone (from
/// `CoachCore`) so parsing/formatting is host-independent.
enum WireDateFormatters {
  /// Calendar-date formatter — `yyyy-MM-dd` (lowercase Unicode pattern: `y` = calendar year,
  /// `d` = day-of-month). **Never** `YYYY`/`DD` (week-year / day-of-year — a classic Foundation
  /// footgun that mis-parses around year boundaries). Configured once, then only read.
  static let calendarDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .europeSofia
    formatter.calendar = .europeSofia
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  /// ISO-8601 instant formatter that tolerates fractional seconds on decode.
  ///
  /// `nonisolated(unsafe)`: `ISO8601DateFormatter` is not `Sendable`, but it is only ever read
  /// (parse / format) after this one-time configuration — Foundation date formatters are
  /// thread-safe for concurrent read use.
  nonisolated(unsafe) static let isoInstantWithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .europeSofia
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  /// ISO-8601 instant formatter for whole-second timestamps (and the canonical encode form).
  /// `nonisolated(unsafe)`: see ``isoInstantWithFractionalSeconds`` — read-only after setup.
  nonisolated(unsafe) static let isoInstant: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .europeSofia
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// Parse any wire `Date` string, disambiguating `date` from `date-time` by the presence of a
  /// time component (`T`). Returns `nil` on a value matching neither shape (the caller turns this
  /// into a real decode error — the strategy is never silently lossy).
  static func parse(_ string: String) -> Date? {
    if string.contains("T") {
      return parseISOInstant(string)
    }
    return parseCalendarDate(string)
  }

  /// Parse a `yyyy-MM-dd` calendar date (midnight, Europe/Sofia).
  static func parseCalendarDate(_ string: String) -> Date? {
    calendarDate.date(from: string)
  }

  /// Parse an ISO-8601 instant, with then without fractional seconds.
  static func parseISOInstant(_ string: String) -> Date? {
    isoInstantWithFractionalSeconds.date(from: string) ?? isoInstant.date(from: string)
  }

  /// Render a calendar date as `yyyy-MM-dd`.
  static func calendarString(from date: Date) -> String {
    calendarDate.string(from: date)
  }

  /// Render an instant as a Europe/Sofia ISO-8601 `date-time` string.
  static func isoString(from date: Date) -> String {
    isoInstant.string(from: date)
  }
}
