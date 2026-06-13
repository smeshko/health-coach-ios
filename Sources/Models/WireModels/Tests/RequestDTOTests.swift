import DomainModels
import Foundation
import Testing

@testable import WireModels

struct RequestDTOTests {
  private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try WireCoder.decoder.decode(type, from: Data(json.utf8))
  }

  private func roundTrip<T: Codable & Equatable>(_ type: T.Type, from json: String) throws -> T {
    let first = try decode(type, from: json)
    let reencoded = try WireCoder.encoder.encode(first)
    let second = try WireCoder.decoder.decode(type, from: reencoded)
    #expect(first == second, "decode → encode → decode must be value-equal")
    return first
  }

  @Test func test_syncRequest_emptyBody_encodesEmptyArrays() throws {
    let data = try WireCoder.encoder.encode(SyncRequest())
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect((object["records"] as? [Any])?.isEmpty == true)
    #expect((object["workouts"] as? [Any])?.isEmpty == true)
    #expect((object["activitySummary"] as? [Any])?.isEmpty == true)
    #expect(object["checkin"] == nil)
    #expect(object["strengthTest"] == nil)
  }

  /// `SyncRequest` is encode-only (the client never decodes a `/sync` body). Assert the encoded JSON:
  /// string-valued metadata, and the always-empty `statistics` / nil `zoneMinutes` keys are omitted.
  @Test func test_syncRequest_fullBody_encodesExpectedShape() throws {
    let day = Date(timeIntervalSince1970: 1_780_000_000)
    let request = SyncRequest(
      records: [
        HealthRecord(
          uuid: "rec-1", type: .heartRate, start: day, end: day,
          value: 142, unit: "count/min", source: "Apple Watch",
          metadata: ["context": "workout"]
        ),
      ],
      workouts: [
        Workout(
          uuid: "wk-1", type: "HKWorkoutActivityTypeRunning", start: day, end: day,
          durationS: 2700, distanceM: 8000, activeEnergyKcal: 540, effortScore: 7
        ),
      ],
      activitySummary: [
        ActivitySummary(
          date: WireCalendarDate(day), activeEnergyKcal: 720, exerciseMinutes: 52,
          standHours: 11, steps: 9123
        ),
      ],
      checkin: CheckIn(date: day, giSymptoms: false, kneePain: 1, illness: false),
      strengthTest: StrengthTest(date: day, maxPushups: 42, maxPullups: 14)
    )
    let data = try WireCoder.encoder.encode(request)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    let workout = try #require((object["workouts"] as? [[String: Any]])?.first)
    #expect(workout["statistics"] == nil, "the always-empty statistics key is no longer emitted")
    #expect(workout["zoneMinutes"] == nil, "nil zoneMinutes is omitted")
    #expect(workout["effortScore"] as? Int == 7)

    let record = try #require((object["records"] as? [[String: Any]])?.first)
    #expect(record["metadata"] as? [String: String] == ["context": "workout"])
    #expect(object["checkin"] != nil)
    #expect(object["strengthTest"] != nil)
  }

  @Test func test_dailyBriefRequest_absentDate() throws {
    let request = try roundTrip(DailyBriefRequest.self, from: "{}")
    #expect(request.date == nil)
    #expect(request == DailyBriefRequest(date: nil))
    // Folded the empty-body encode pin here (audit MERGE — moved from DecodeRoundTripTests): an
    // absent-date request re-encodes to the empty object the server accepts.
    let encoded = try #require(String(bytes: WireCoder.encoder.encode(DailyBriefRequest()), encoding: .utf8))
    #expect(encoded == "{}")
  }

  @Test func test_weeklyBriefRequest_absentIsoWeek() throws {
    let request = try roundTrip(WeeklyBriefRequest.self, from: "{}")
    #expect(request.isoWeek == nil)
    #expect(request == WeeklyBriefRequest(isoWeek: nil))
    let encoded = try #require(String(bytes: WireCoder.encoder.encode(WeeklyBriefRequest()), encoding: .utf8))
    #expect(encoded == "{}")
  }
}
