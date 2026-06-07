import CoachCore
import Foundation
@testable import WireModels
import XCTest

final class DecodeRoundTripTests: XCTestCase {
  // MARK: - Helpers

  private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try WireCoder.decoder.decode(type, from: Data(json.utf8))
  }

  private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    try WireCoder.decoder.decode(type, from: data)
  }

  private func encodedString(_ value: some Encodable) throws -> String {
    try XCTUnwrap(String(bytes: WireCoder.encoder.encode(value), encoding: .utf8))
  }

  /// Assert `decode → encode → decode` yields a value equal to the first decode.
  private func assertRoundTrips(
    _ type: (some Codable & Equatable).Type, from json: String, line: UInt = #line
  ) throws {
    let first = try decode(type, from: json)
    let second = try decode(type, from: WireCoder.encoder.encode(first))
    XCTAssertEqual(first, second, "round-trip must be value-equal", line: line)
  }

  // MARK: - Round-trip every top-level response

  func test_roundTrip_dailyBrief() throws { try assertRoundTrips(DailyBrief.self, from: Fixtures.dailyBrief) }
  func test_roundTrip_weeklyPlan() throws { try assertRoundTrips(WeeklyPlan.self, from: Fixtures.weeklyPlan) }
  func test_roundTrip_profile() throws {
    try assertRoundTrips(ProfileResponse.self, from: Fixtures.profileResponse)
  }

  func test_roundTrip_syncResponse() throws {
    try assertRoundTrips(SyncResponse.self, from: Fixtures.syncResponse)
  }

  func test_roundTrip_healthResponse() throws {
    try assertRoundTrips(HealthResponse.self, from: Fixtures.healthResponse)
  }

  func test_roundTrip_errorResponse() throws {
    try assertRoundTrips(ErrorResponse.self, from: Fixtures.errorResponse)
  }

  // MARK: - Mixed date + date-time in one payload

  func test_dailyBrief_mixedDateAndDateTime() throws {
    let brief = try decode(DailyBrief.self, from: Fixtures.dailyBrief)

    // `data.date` is a calendar date (Europe/Sofia midnight on 2026-06-06).
    let dateParts = Calendar.europeSofia.dateComponents(
      [.year, .month, .day, .hour], from: brief.data.date.value
    )
    XCTAssertEqual(dateParts.year, 2026)
    XCTAssertEqual(dateParts.month, 6)
    XCTAssertEqual(dateParts.day, 6)
    XCTAssertEqual(dateParts.hour, 0)

    // `data.generatedAt` is a date-time instant: 07:30:00+03:00 == 04:30:00 UTC.
    var utc = Calendar(identifier: .iso8601)
    utc.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
    let expected = try XCTUnwrap(
      utc.date(from: DateComponents(year: 2026, month: 6, day: 6, hour: 4, minute: 30))
    )
    XCTAssertEqual(brief.data.generatedAt.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.001)
  }

  /// A winter (`+02:00`, no-DST) `date-time` decodes to the right instant and re-encodes with the
  /// winter Sofia offset — proving the encode path is DST-aware, not just the June `+03:00` case.
  func test_dateTime_winterInstantIsDstAware() throws {
    let json = #"{ "status": "ok", "serverTime": "2026-01-15T07:30:00+02:00" }"#
    let response = try decode(HealthResponse.self, from: json)

    var utc = Calendar(identifier: .iso8601)
    utc.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
    let expected = try XCTUnwrap(
      utc.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 5, minute: 30))
    )
    XCTAssertEqual(response.serverTime.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.001)

    let reencoded = try encodedString(response)
    XCTAssertTrue(reencoded.contains("+02:00"), "winter instant must encode with Sofia's +02:00 offset: \(reencoded)")
    try assertRoundTrips(HealthResponse.self, from: json)
  }

  // MARK: - Null vs absent are identical

  func test_nullVsAbsent_areIdentical() throws {
    let withNull = try decode(IntakeSummary.self, from: Fixtures.intakeNullMacros)
    let withAbsent = try decode(IntakeSummary.self, from: Fixtures.intakeAbsentMacros)
    XCTAssertNil(withNull.caloriesKcal)
    XCTAssertNil(withAbsent.caloriesKcal)
    XCTAssertNil(withNull.waterL)
    XCTAssertNil(withAbsent.waterL)
    XCTAssertEqual(withNull, withAbsent)
  }

  // MARK: - Unknown enum / unknown flag do not crash

  func test_unknownEnumRawValue_doesNotCrash() throws {
    let json = Fixtures.dailyBrief.replacingOccurrences(of: #""easy_run""#, with: #""warp_drive""#)
    let brief = try decode(DailyBrief.self, from: json)
    XCTAssertEqual(brief.data.session.card, .unknown("warp_drive"))
    // The rest of the brief is intact.
    XCTAssertEqual(brief.data.readiness.band, .known(.green))
    XCTAssertEqual(brief.data.session.intensity, .known(.easy))
    // Re-encode preserves the raw string.
    let reencoded = try encodedString(brief)
    XCTAssertTrue(reencoded.contains("warp_drive"), "unknown card must round-trip its raw value")
  }

  func test_unknownEnum_optionalAndArrayNestedDoNotCrash() throws {
    // Optional enum field (SafetyGate.overrideTo).
    let gate = try decode(
      SafetyGate.self, from: #"{"triggered":true,"reasons":[],"overrideTo":"warp_drive"}"#
    )
    XCTAssertEqual(gate.overrideTo, .unknown("warp_drive"))

    // Array-nested enums (narrative[].type, core[].card) + an optional enum nested in an array
    // (core[].suggestedDay) — all must decode to `.unknown`, never throw.
    let json = Fixtures.weeklyPlan
      .replacingOccurrences(of: #""type": "plan""#, with: #""type": "moon_calendar""#)
      .replacingOccurrences(of: #""card": "long_run""#, with: #""card": "warp_drive""#)
      .replacingOccurrences(of: #""suggestedDay": "sun""#, with: #""suggestedDay": "someday""#)
    let plan = try decode(WeeklyPlan.self, from: json)
    XCTAssertEqual(plan.narrative.first?.type, .unknown("moon_calendar"))
    XCTAssertEqual(plan.data.core.first?.card, .unknown("warp_drive"))
    XCTAssertEqual(plan.data.core.first?.suggestedDay, .unknown("someday"))
  }

  func test_unknownFlagString_doesNotCrash() throws {
    let json = Fixtures.dailyBrief.replacingOccurrences(
      of: #""flags": ["zone2"]"#, with: #""flags": ["taper", "moon_phase"]"#
    )
    let brief = try decode(DailyBrief.self, from: json)
    XCTAssertEqual(brief.data.session.flags, ["taper", "moon_phase"])
  }

  // MARK: - A tripped safety gate is a normal 200 brief

  func test_forcedRest_safetyGateIsNormal200() throws {
    let brief = try decode(DailyBrief.self, from: Fixtures.dailyBriefForcedRest)
    XCTAssertTrue(brief.data.safetyGate.triggered)
    XCTAssertEqual(brief.data.safetyGate.reasons, ["illness", "knee_pain"])
    XCTAssertEqual(brief.data.safetyGate.overrideTo, .known(.rest))
    XCTAssertEqual(brief.data.session.card, .known(.rest))
    XCTAssertTrue(brief.data.alternatives.isEmpty)
    try assertRoundTrips(DailyBrief.self, from: Fixtures.dailyBriefForcedRest)
  }

  // MARK: - Request bodies: empty body + format:date encode

  func test_syncRequest_emptyAndFullRoundTrip() throws {
    try assertRoundTrips(SyncRequest.self, from: "{}")
    let empty = try decode(SyncRequest.self, from: "{}")
    XCTAssertEqual(empty, SyncRequest())
  }

  func test_briefRequests_emptyBody() throws {
    XCTAssertEqual(try decode(DailyBriefRequest.self, from: "{}"), DailyBriefRequest(date: nil))
    XCTAssertEqual(try decode(WeeklyBriefRequest.self, from: "{}"), WeeklyBriefRequest(isoWeek: nil))
    // Both re-encode to a body the server accepts (empty object).
    XCTAssertEqual(try encodedString(DailyBriefRequest()), "{}")
    XCTAssertEqual(try encodedString(WeeklyBriefRequest()), "{}")
  }

  func test_formatDateField_encodesAsDateOnly() throws {
    let day = try XCTUnwrap(
      Calendar.europeSofia.date(from: DateComponents(year: 2026, month: 6, day: 6))
    )
    let request = SyncRequest(
      activitySummary: [
        ActivitySummary(
          date: WireCalendarDate(day), activeEnergyKcal: 720, exerciseMinutes: 52, standHours: 11
        ),
      ]
    )
    let json = try encodedString(request)
    XCTAssertTrue(json.contains(#""date":"2026-06-06""#), "format:date must encode as bare yyyy-MM-dd: \(json)")
    XCTAssertFalse(json.contains("2026-06-06T"), "format:date must not encode as a date-time: \(json)")

    let briefRequest = DailyBriefRequest(date: WireCalendarDate(day))
    XCTAssertEqual(try encodedString(briefRequest), #"{"date":"2026-06-06"}"#)
  }
}
