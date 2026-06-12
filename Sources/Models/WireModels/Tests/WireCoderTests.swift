import CoachCore
import DomainModels
import Foundation
import Testing

@testable import WireModels

struct WireCoderTests {
  // MARK: - Helpers

  private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try WireCoder.decoder.decode(type, from: Data(json.utf8))
  }

  private func encodedString(_ value: some Encodable) throws -> String {
    let data = try WireCoder.encoder.encode(value)
    return try #require(String(bytes: data, encoding: .utf8))
  }

  /// An instant built host-independently from UTC components.
  private func utcInstant(
    year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0
  ) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
      from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute, second: second
      )
    )!
  }

  // Wrapper structs that route a `Date` through `WireCoder`'s shared date strategy.
  private struct PlainDateBox: Codable, Equatable {
    var value: Date
  }

  private struct CalendarDateBox: Codable, Equatable {
    var date: WireCalendarDate
  }

  private struct OptionalCalendarDateBox: Codable, Equatable {
    var date: WireCalendarDate?
  }

  // MARK: - Decoder: date strategy

  @Test func test_decoder_parsesDateOnly() throws {
    let box = try decode(PlainDateBox.self, from: #"{"value":"2026-06-06"}"#)
    let components = Calendar.europeSofia.dateComponents([.year, .month, .day, .hour], from: box.value)
    #expect(components.year == 2026)
    #expect(components.month == 6)
    #expect(components.day == 6)
    #expect(components.hour == 0)
  }

  @Test func test_decoder_parsesDateTimeWithOffsetAndFractionalSeconds() throws {
    // 07:30:00+03:00 == 04:30:00 UTC
    let whole = try decode(PlainDateBox.self, from: #"{"value":"2026-06-06T07:30:00+03:00"}"#)
    #expect(
      abs(
        whole.value.timeIntervalSince1970
          - utcInstant(year: 2026, month: 6, day: 6, hour: 4, minute: 30).timeIntervalSince1970
      ) <= 0.001
    )

    // 07:30:00.123+03:00 == 04:30:00.123 UTC
    let fractional = try decode(PlainDateBox.self, from: #"{"value":"2026-06-06T07:30:00.123+03:00"}"#)
    #expect(
      abs(
        fractional.value.timeIntervalSince1970
          - (utcInstant(year: 2026, month: 6, day: 6, hour: 4, minute: 30).timeIntervalSince1970 + 0.123)
      ) <= 0.001
    )

    // 07:30:00+02:00 == 05:30:00 UTC (different instant from the +03:00 case)
    let otherOffset = try decode(PlainDateBox.self, from: #"{"value":"2026-06-06T07:30:00+02:00"}"#)
    #expect(
      abs(
        otherOffset.value.timeIntervalSince1970
          - utcInstant(year: 2026, month: 6, day: 6, hour: 5, minute: 30).timeIntervalSince1970
      ) <= 0.001
    )
  }

  @Test func test_decoder_rejectsGarbageDate() {
    #expect(throws: (any Error).self) {
      try decode(PlainDateBox.self, from: #"{"value":"not-a-date"}"#)
    }
  }

  // MARK: - WireCalendarDate

  @Test func test_calendarDate_encodesAsDateOnly() throws {
    let box = try decode(CalendarDateBox.self, from: #"{"date":"2026-06-06"}"#)
    let json = try encodedString(box)
    #expect(json.contains(#""date":"2026-06-06""#), "expected bare yyyy-MM-dd, got \(json)")
    #expect(!json.contains("T"), "must not emit an ISO-8601 instant, got \(json)")

    // decode → encode → decode is value-equal
    let roundTripped = try decode(CalendarDateBox.self, from: json)
    #expect(roundTripped == box)
  }

  @Test func test_calendarDate_optionalRoundTripsAbsentAndNull() throws {
    let absent = try decode(OptionalCalendarDateBox.self, from: "{}")
    #expect(absent.date == nil)

    let explicitNull = try decode(OptionalCalendarDateBox.self, from: #"{"date":null}"#)
    #expect(explicitNull.date == nil)
    #expect(absent == explicitNull)

    let present = try decode(OptionalCalendarDateBox.self, from: #"{"date":"2026-06-06"}"#)
    #expect(present.date != nil)
    let roundTripped = try decode(OptionalCalendarDateBox.self, from: encodedString(present))
    #expect(roundTripped == present)
  }

  // MARK: - Shared closed enums (strict decode)

  @Test func test_enum_knownRawValuesRoundTrip() throws {
    #expect(try decode(Card.self, from: #""easy_run""#) == .easyRun)
    #expect(try decode(RecordType.self, from: #""heart_rate""#) == .heartRate)
    #expect(try decode(Zone.self, from: #""z1""#) == .z1)
    #expect(try decode(ErrorCode.self, from: #""validation_error""#) == .validationError)

    #expect(try encodedString(Card.easyRun) == #""easy_run""#)
  }

  @Test func test_enum_unknownRawValueThrows() throws {
    // The shared closed enums own the API contract → an out-of-set value is a hard decode error,
    // never a tolerant fallback (Phase 11.3 strict decode).
    #expect(throws: DecodingError.self) {
      _ = try decode(Card.self, from: #""warp_drive""#)
    }
  }
}
