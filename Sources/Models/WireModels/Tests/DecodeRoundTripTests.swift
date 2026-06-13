import CoachCore
import Foundation
import SampleData
import Testing

@testable import WireModels

// Note: `DomainModels` is intentionally NOT imported — the shared closed-enum cases (`.green`,
// `.rest`, …) resolve via the DTO field's inferred type, and importing it would collide DTO struct
// names (both modules export `DailyBrief`, `WeeklyPlan`, …). `import SampleData` is safe: it brings
// only `SampleData`/`SampleScenario` (not DomainModels' types) into scope.
//
// Phase 11.6 (TASK-003): the canonical-shape fixtures now decode the SAME bytes `SampleData` ships
// (one truth) — this suite merges the former ResponseDTOTests' decode + field asserts with the
// round-trips. Only genuinely-divergent shapes (the error envelope, null-vs-absent intake) stay as
// justified inline survivors in `Fixtures.swift`.
struct DecodeRoundTripTests {
  // MARK: - Helpers

  private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try WireCoder.decoder.decode(type, from: Data(json.utf8))
  }

  private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    try WireCoder.decoder.decode(type, from: data)
  }

  /// The raw canonical bytes `SampleData` ships for a scenario (the single fixture source).
  private func sample(_ scenario: SampleScenario) throws -> Data {
    try SampleData.jsonData(for: scenario)
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

  private func assertRoundTrips(
    _ type: (some Codable & Equatable).Type, from data: Data,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let first = try decode(type, from: data)
    let second = try decode(type, from: WireCoder.encoder.encode(first))
    #expect(first == second, "round-trip must be value-equal", sourceLocation: sourceLocation)
  }

  // MARK: - Decode + field asserts + round-trip per canonical fixture (merged from ResponseDTOTests)

  @Test func test_dailyBrief_decodesAndRoundTrips() throws {
    let brief = try decode(DailyBrief.self, from: sample(.dailyBriefGreen))
    #expect(brief.data.readiness.band == .green)
    #expect(brief.data.session.card == .easyRun)
    #expect(!brief.narrative.isEmpty)
    try assertRoundTrips(DailyBrief.self, from: sample(.dailyBriefGreen))
  }

  @Test func test_weeklyPlan_decodesAndRoundTrips() throws {
    let plan = try decode(WeeklyPlan.self, from: sample(.weeklyPlanDeload))
    #expect(plan.data.isoWeek == "2026-W24")
    #expect(plan.data.core.first?.card == .easyRun)
    try assertRoundTrips(WeeklyPlan.self, from: sample(.weeklyPlanDeload))
  }

  @Test func test_profile_decodesAndRoundTrips() throws {
    let profile = try decode(ProfileResponse.self, from: sample(.profile))
    #expect(profile.zones.z1.low == 100)
    #expect(profile.thresholds.maxHr == 190)
    #expect(profile.meta.constitutionVersion == "v3")
    try assertRoundTrips(ProfileResponse.self, from: sample(.profile))
  }

  @Test func test_syncResponse_decodesAndRoundTrips() throws {
    let response = try decode(SyncResponse.self, from: sample(.syncResponse))
    #expect(response.recordsUpserted == 128)
    #expect(response.checkinSaved)
    try assertRoundTrips(SyncResponse.self, from: sample(.syncResponse))
  }

  @Test func test_errorResponse_decodesAndRoundTrips() throws {
    // Justified inline survivor: SampleData ships no error-envelope resource.
    let envelope = try decode(ErrorResponse.self, from: Fixtures.errorResponse)
    #expect(envelope.error.code == .validationError)
    #expect(envelope.error.detail == "date must be yyyy-MM-dd")
    try assertRoundTrips(ErrorResponse.self, from: Fixtures.errorResponse)
  }

  // MARK: - Mixed date + date-time in one payload

  @Test func test_dailyBrief_mixedDateAndDateTime() throws {
    let brief = try decode(DailyBrief.self, from: sample(.dailyBriefGreen))

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
    // Justified inline survivors: SampleData ships no null-macros / absent-macros intake resource.
    let withNull = try decode(IntakeSummary.self, from: Fixtures.intakeNullMacros)
    let withAbsent = try decode(IntakeSummary.self, from: Fixtures.intakeAbsentMacros)
    #expect(withNull.caloriesKcal == nil)
    #expect(withAbsent.caloriesKcal == nil)
    #expect(withNull.waterL == nil)
    #expect(withAbsent.waterL == nil)
    #expect(withNull == withAbsent)
    // Folded from ResponseDTOTests.test_intakeSummary_vsTargetRequiredWithNullMacros (audit MERGE):
    // `vsTarget` is required and survives even when every macro total is null.
    #expect(withNull.vsTarget.caloriesPct == withAbsent.vsTarget.caloriesPct)
  }

  // MARK: - Unknown closed-enum value is a hard decode error (strict, self-owned API)

  @Test func test_unknownEnumRawValue_throws() throws {
    // The closed enums are now shared wire↔domain and decode strictly — an out-of-set `card`
    // value must reject the whole brief with a `DecodingError` (Phase 11.3), not fall back.
    // String-surgery rebased onto the canonical SampleData bytes (TASK-003).
    let text = try #require(String(data: sample(.dailyBriefGreen), encoding: .utf8))
    let json = text.replacingOccurrences(of: #""easy_run""#, with: #""warp_drive""#)
    #expect(throws: DecodingError.self) {
      _ = try decode(DailyBrief.self, from: json)
    }
  }

  @Test func test_unknownEnum_optionalAndArrayNestedThrow() throws {
    // Optional enum field (SafetyGate.overrideTo) — strict decode throws on an out-of-set value.
    #expect(throws: DecodingError.self) {
      _ = try decode(
        SafetyGate.self, from: #"{"triggered":true,"reasons":[],"overrideTo":"warp_drive"}"#
      )
    }

    // Array-nested closed enum (core[].card) likewise rejects the whole payload — surgery rebased onto
    // the canonical deload bytes (its core carries a `strength_full` card).
    let text = try #require(String(data: sample(.weeklyPlanDeload), encoding: .utf8))
    let json = text.replacingOccurrences(of: #""card": "strength_full""#, with: #""card": "warp_drive""#)
    #expect(throws: DecodingError.self) {
      _ = try decode(WeeklyPlan.self, from: json)
    }
  }

  // MARK: - Missing required field is a hard decode error

  @Test func test_dailyBrief_missingReadiness_throws() throws {
    // A daily brief with the required `readiness` object absent must reject with a `DecodingError`.
    let json = """
    {
      "data": {
        "date": "2026-06-06",
        "safetyGate": { "triggered": false, "reasons": [] },
        "session": {
          "card": "easy_run", "intensity": "easy",
          "durationMinLow": 40, "durationMinHigh": 55, "flags": []
        },
        "alternatives": [],
        "skipOk": true,
        "macroFocus": {
          "dayType": "moderate", "caloriesKcal": 2600, "proteinG": 170, "carbsG": 300,
          "fatGLow": 60, "fatGHigh": 80, "hydrationLLow": 2.5, "hydrationLHigh": 3.5
        },
        "generatedAt": "2026-06-06T07:30:00+03:00",
        "cached": false
      },
      "narrative": []
    }
    """
    #expect(throws: DecodingError.self) {
      _ = try decode(DailyBrief.self, from: json)
    }
  }

  /// Kept standalone (only null-`totalRunKm` coverage anywhere — moved here from ResponseDTOTests
  /// when the two decode files merged, TASK-003).
  @Test func test_weeklyTargets_totalRunKmNull() throws {
    let json = """
    {
      "totalRunKm": null,
      "easyRunRatio": 0.8,
      "strengthSessions": 2,
      "hardDays": 2,
      "cadenceSpm": 178
    }
    """
    let targets = try decode(WeeklyTargets.self, from: json)
    #expect(targets.totalRunKm == nil)
    #expect(targets.cadenceSpm == 178)
  }

  @Test func test_intakeSummary_missingVsTarget_throws() throws {
    // `vsTarget` is required on `IntakeSummary`; an absent key must reject the payload.
    let json = """
    {
      "date": "2026-06-06",
      "caloriesKcal": null,
      "proteinG": null
    }
    """
    #expect(throws: DecodingError.self) {
      _ = try decode(IntakeSummary.self, from: json)
    }
  }

  // MARK: - A tripped safety gate is a normal 200 brief

  @Test func test_forcedRest_safetyGateIsNormal200() throws {
    // Re-pointed at the canonical rest-illness scenario (TASK-003): a tripped gate is a normal 200.
    let brief = try decode(DailyBrief.self, from: sample(.dailyBriefRestIllness))
    #expect(brief.data.safetyGate.triggered)
    #expect(brief.data.safetyGate.reasons == ["illness"])
    #expect(brief.data.safetyGate.overrideTo == .rest)
    #expect(brief.data.session.card == .rest)
    #expect(brief.data.alternatives.isEmpty)
    try assertRoundTrips(DailyBrief.self, from: sample(.dailyBriefRestIllness))
  }

  // MARK: - Request body: format:date encode (empty-body pins moved to RequestDTOTests — audit MERGE)

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

    // Folded from WireCoderTests.test_calendarDate_encodesAsDateOnly (audit MERGE — one home for the
    // bare yyyy-MM-dd claim): a `WireCalendarDate` decode → encode → decode is value-equal.
    let decodedBack = try decode(DailyBriefRequest.self, from: Data(#"{"date":"2026-06-06"}"#.utf8))
    #expect(decodedBack.date == WireCalendarDate(day))
  }
}
