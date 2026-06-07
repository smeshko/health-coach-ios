import Foundation

/// A `format: date` (`yyyy-MM-dd`) calendar-date value.
///
/// A single `.custom` `JSONEncoder` date strategy cannot distinguish a calendar-date `Date` from
/// an instant `Date` (it receives a bare `Date` with no field context), so it would serialise a
/// `format: date` field as a full ISO-8601 `date-time` string — which the server's Pydantic native
/// `date` validation rejects with `422` (DECISIONS.md Decision 2). To keep the wire correct, the
/// seven `format: date` fields use this dedicated type, which owns its own `yyyy-MM-dd`
/// encode/decode and bypasses `WireCoder`'s date strategy entirely.
///
/// Modelled as a value type (not a property wrapper) so `Optional<WireCalendarDate>` round-trips
/// absent/`null` → `nil` via the parent's synthesised `decodeIfPresent` for free (DECISIONS.md
/// Decision 2 sanctions either form).
public struct WireCalendarDate: Codable, Sendable, Equatable, Hashable {
  /// The underlying instant — midnight in Europe/Sofia on the calendar day.
  public var value: Date

  public init(_ value: Date) {
    self.value = value
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    guard let date = WireDateFormatters.parseCalendarDate(string) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected a `yyyy-MM-dd` calendar date, got '\(string)'"
      )
    }
    value = date
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(WireDateFormatters.calendarString(from: value))
  }
}
