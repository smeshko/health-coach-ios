import CoachCore
import Foundation
import Testing

@testable import WireModels

struct DecodeRoundTripTests {
  // MARK: - Helpers

  private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try WireCoder.decoder.decode(type, from: Data(json.utf8))
  }

  private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    try WireCoder.decoder.decode(type, from: data)
  }

  private func encodedString(_ value: some Encodable) throws -> String {
    try #require(String(bytes: WireCoder.encoder.encode(value), encoding: .utf8))
  }

  /// Assert `decode → encode → decode` yields a value equal to the first decode.
  private func assertRoundTrips(
    _ type: (some Codable & Equatable).Type, from json: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let first = try decode(type, from: json)
    let second = try decode(type, from: WireCoder.encoder.encode(first))
    #expect(first == second, "round-trip must be value-equal", sourceLocation: sourceLocation)
  }

  // MARK: - Round-trip every top-level response

  @Test func test_roundTrip_dailyBrief() throws { try assertRoundTrips(DailyBrief.self, from: Fixtures.dailyBrief) }
  @Test func test_roundTrip_weeklyPlan() throws { try assertRoundTrips(WeeklyPlan.self, from: Fixtures.weeklyPlan) }
  @Test func test_roundTrip_profile() throws {
    try assertRoundTrips(ProfileResponse.self, from: Fixtures.profileResponse)
  }

  @Test func test_roundTrip_syncResponse() throws {
    try assertRoundTrips(SyncResponse.self, from: Fixtures.syncResponse)
  }

  @Test func test_roundTrip_errorResponse() throws {
    try assertRoundTrips(ErrorResponse.self, from: Fixtures.errorResponse)
  }

  // MARK: - Mixed date + date-time in one payload

  @Test func test_dailyBrief_mixedDateAndDateTime() throws {
    let brief = try decode(DailyBrief.self, from: Fixtures.dailyBrief)

    // `data.date` is a calendar date (Europe/Sofia midnight on 2026-06-06).
    let dateParts = Calendar.europeSofia.dateComponents(
      [.year, .month, .day, .hour], from: brief.data.date.value
    )
    #expect(dateParts.year == 2026)
    #expect(dateParts.month == 6)
    #expect(dateParts.day == 6)
    #expect(dateParts.hour == 0)

    // `data.generatedAt` is a date-time instant: 07:30:00+03:00 == 04:30:00 UTC.
    var utc = Calendar(identifier: .iso8601)
    utc.timeZone = try #require(TimeZone(identifier: "UTC"))
    let expected = try #require(
      utc.date(from: DateComponents(year: 2026, month: 6, day: 6, hour: 4, minute: 30))
    )
    #expect(abs(brief.data.generatedAt.timeIntervalSince1970 - expected.timeIntervalSince1970) <= 0.001)
  }

  /// A winter (`+02:00`, no-DST) `date-time` decodes to the right instant and re-encodes with the
  /// winter Sofia offset — proving the encode path is DST-aware, not just the June `+03:00` case.
  @Test func test_dateTime_winterInstantIsDstAware() throws {
    let json = #"""
    {
      "recordsUpserted": 0,
      "recordsDuplicate": 0,
      "workoutsUpserted": 0,
      "activityDaysUpserted": 0,
      "checkinSaved": false,
      "strengthTestSaved": false,
      "serverTime": "2026-01-15T07:30:00+02:00"
    }
    """#
    let response = try decode(SyncResponse.self, from: json)

    var utc = Calendar(identifier: .iso8601)
    utc.timeZone = try #require(TimeZone(identifier: "UTC"))
    let expected = try #require(
      utc.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 5, minute: 30))
    )
    #expect(abs(response.serverTime.timeIntervalSince1970 - expected.timeIntervalSince1970) <= 0.001)

    let reencoded = try encodedString(response)
    #expect(reencoded.contains("+02:00"), "winter instant must encode with Sofia's +02:00 offset: \(reencoded)")
    try assertRoundTrips(SyncResponse.self, from: json)
  }

  // MARK: - Null vs absent are identical

  @Test func test_nullVsAbsent_areIdentical() throws {
    let withNull = try decode(IntakeSummary.self, from: Fixtures.intakeNullMacros)
    let withAbsent = try decode(IntakeSummary.self, from: Fixtures.intakeAbsentMacros)
    #expect(withNull.caloriesKcal == nil)
    #expect(withAbsent.caloriesKcal == nil)
    #expect(withNull.waterL == nil)
    #expect(withAbsent.waterL == nil)
    #expect(withNull == withAbsent)
  }

  // MARK: - Unknown enum / unknown flag do not crash

  @Test func test_unknownEnumRawValue_doesNotCrash() throws {
    let json = Fixtures.dailyBrief.replacingOccurrences(of: #""easy_run""#, with: #""warp_drive""#)
    let brief = try decode(DailyBrief.self, from: json)
    #expect(brief.data.session.card == .unknown("warp_drive"))
    // The rest of the brief is intact.
    #expect(brief.data.readiness.band == .known(.green))
    #expect(brief.data.session.intensity == .known(.easy))
    // Re-encode preserves the raw string.
    let reencoded = try encodedString(brief)
    #expect(reencoded.contains("warp_drive"), "unknown card must round-trip its raw value")
  }

  @Test func test_unknownEnum_optionalAndArrayNestedDoNotCrash() throws {
    // Optional enum field (SafetyGate.overrideTo).
    let gate = try decode(
      SafetyGate.self, from: #"{"triggered":true,"reasons":[],"overrideTo":"warp_drive"}"#
    )
    #expect(gate.overrideTo == .unknown("warp_drive"))

    // Array-nested enums (narrative[].type, core[].card) + an optional enum nested in an array
    // (core[].suggestedDay) — all must decode to `.unknown`, never throw.
    let json = Fixtures.weeklyPlan
      .replacingOccurrences(of: #""type": "plan""#, with: #""type": "moon_calendar""#)
      .replacingOccurrences(of: #""card": "long_run""#, with: #""card": "warp_drive""#)
      .replacingOccurrences(of: #""suggestedDay": "sun""#, with: #""suggestedDay": "someday""#)
    let plan = try decode(WeeklyPlan.self, from: json)
    #expect(plan.narrative.first?.type == .unknown("moon_calendar"))
    #expect(plan.data.core.first?.card == .unknown("warp_drive"))
    #expect(plan.data.core.first?.suggestedDay == .unknown("someday"))
  }

  @Test func test_unknownFlagString_doesNotCrash() throws {
    let json = Fixtures.dailyBrief.replacingOccurrences(
      of: #""flags": ["zone2"]"#, with: #""flags": ["taper", "moon_phase"]"#
    )
    let brief = try decode(DailyBrief.self, from: json)
    #expect(brief.data.session.flags == ["taper", "moon_phase"])
  }

  // MARK: - A tripped safety gate is a normal 200 brief

  @Test func test_forcedRest_safetyGateIsNormal200() throws {
    let brief = try decode(DailyBrief.self, from: Fixtures.dailyBriefForcedRest)
    #expect(brief.data.safetyGate.triggered)
    #expect(brief.data.safetyGate.reasons == ["illness", "knee_pain"])
    #expect(brief.data.safetyGate.overrideTo == .known(.rest))
    #expect(brief.data.session.card == .known(.rest))
    #expect(brief.data.alternatives.isEmpty)
    try assertRoundTrips(DailyBrief.self, from: Fixtures.dailyBriefForcedRest)
  }

  // MARK: - Request bodies: empty body + format:date encode

  @Test func test_syncRequest_emptyAndFullRoundTrip() throws {
    try assertRoundTrips(SyncRequest.self, from: "{}")
    let empty = try decode(SyncRequest.self, from: "{}")
    #expect(empty == SyncRequest())
  }

  @Test func test_briefRequests_emptyBody() throws {
    #expect(try decode(DailyBriefRequest.self, from: "{}") == DailyBriefRequest(date: nil))
    #expect(try decode(WeeklyBriefRequest.self, from: "{}") == WeeklyBriefRequest(isoWeek: nil))
    // Both re-encode to a body the server accepts (empty object).
    #expect(try encodedString(DailyBriefRequest()) == "{}")
    #expect(try encodedString(WeeklyBriefRequest()) == "{}")
  }

  @Test func test_formatDateField_encodesAsDateOnly() throws {
    let day = try #require(
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
    #expect(json.contains(#""date":"2026-06-06""#), "format:date must encode as bare yyyy-MM-dd: \(json)")
    #expect(!json.contains("2026-06-06T"), "format:date must not encode as a date-time: \(json)")

    let briefRequest = DailyBriefRequest(date: WireCalendarDate(day))
    #expect(try encodedString(briefRequest) == #"{"date":"2026-06-06"}"#)
  }
}
