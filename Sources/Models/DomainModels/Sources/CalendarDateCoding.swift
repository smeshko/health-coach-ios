import CoachCore
import Foundation

/// `yyyy-MM-dd` calendar-date coding for the shared sync-request value types (`CheckIn`,
/// `StrengthTest`). Reimplements WireModels' `WireCalendarDate` formatter configuration locally —
/// DomainModels cannot import WireModels — so the encoded `/sync` JSON is byte-identical: an
/// `en_US_POSIX` locale, Europe/Sofia time zone AND calendar (from CoachCore), and the lowercase
/// `yyyy-MM-dd` pattern (Phase 11.3 D5). A UTC formatter would shift a Sofia-midnight `Date` to the
/// previous calendar day, so the time zone + calendar must match `WireDateFormatters.calendarDate`
/// exactly.
enum CalendarDateCoding {
  static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .europeSofia
    formatter.calendar = .europeSofia
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  /// Decode a `yyyy-MM-dd` string from a keyed container; throws a clean `DecodingError` otherwise.
  static func decode<K: CodingKey>(
    _ container: KeyedDecodingContainer<K>, forKey key: K
  ) throws -> Date {
    let string = try container.decode(String.self, forKey: key)
    guard let date = formatter.date(from: string) else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: container,
        debugDescription: "Expected a `yyyy-MM-dd` calendar date, got '\(string)'"
      )
    }
    return date
  }

  /// Encode a `Date` as its `yyyy-MM-dd` calendar string into a keyed container.
  static func encode<K: CodingKey>(
    _ date: Date, into container: inout KeyedEncodingContainer<K>, forKey key: K
  ) throws {
    try container.encode(formatter.string(from: date), forKey: key)
  }
}
