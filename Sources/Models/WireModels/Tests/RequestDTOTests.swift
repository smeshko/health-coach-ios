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

  @Test func test_syncRequest_emptyBodyDecodes() throws {
    let request = try roundTrip(SyncRequest.self, from: "{}")
    #expect(request.records == [])
    #expect(request.workouts == [])
    #expect(request.activitySummary == [])
    #expect(request.checkin == nil)
    #expect(request.strengthTest == nil)
  }

  @Test func test_syncRequest_fullBodyRoundTrips() throws {
    let request = try roundTrip(SyncRequest.self, from: Self.fullSyncBody)
    #expect(request.records.count == 2)
    #expect(request.records[0].type == .known(.heartRate))
    #expect(request.records[0].value == 142.0)
    #expect(request.records[1].value == nil)
    #expect(request.records[1].category == "asleepCore")
    #expect(request.records[0].metadata == .object([
      "context": .string("workout"),
      "reps": .int(1),
      "rpe": .double(2.5),
    ]))
    #expect(request.workouts.count == 1)
    #expect(request.workouts[0].zoneMinutes?["z2"] == 20.0)
    #expect(request.workouts[0].statistics.count == 1)
    #expect(request.activitySummary.count == 1)
    #expect(request.checkin?.kneePain == 1)
    #expect(request.strengthTest?.maxPushups == 42)
  }

  private static let fullSyncBody = """
  {
    "records": [
      {
        "uuid": "rec-1",
        "type": "heart_rate",
        "start": "2026-06-06T07:30:00+03:00",
        "end": "2026-06-06T07:31:00+03:00",
        "value": 142.0,
        "unit": "count/min",
        "source": "Apple Watch",
        "metadata": { "context": "workout", "reps": 1, "rpe": 2.5 }
      },
      {
        "uuid": "rec-2",
        "type": "sleep_analysis",
        "start": "2026-06-05T23:00:00+03:00",
        "end": "2026-06-06T06:30:00+03:00",
        "category": "asleepCore"
      }
    ],
    "workouts": [
      {
        "uuid": "wk-1",
        "type": "HKWorkoutActivityTypeRunning",
        "start": "2026-06-06T07:00:00+03:00",
        "end": "2026-06-06T07:45:00+03:00",
        "durationS": 2700.0,
        "distanceM": 8000.0,
        "activeEnergyKcal": 540.0,
        "effortScore": 7,
        "zoneMinutes": { "z1": 5.0, "z2": 20.0, "z3": 15.0 },
        "statistics": [
          { "type": "HKQuantityTypeIdentifierHeartRate", "value": 152.0, "unit": "count/min" }
        ]
      }
    ],
    "activitySummary": [
      {
        "date": "2026-06-06",
        "activeEnergyKcal": 720.0,
        "exerciseMinutes": 52,
        "standHours": 11,
        "steps": 9123
      }
    ],
    "checkin": { "date": "2026-06-06", "giSymptoms": false, "kneePain": 1, "illness": false },
    "strengthTest": { "date": "2026-06-06", "maxPushups": 42, "maxPullups": 14 }
  }
  """

  @Test func test_dailyBriefRequest_absentDate() throws {
    let request = try roundTrip(DailyBriefRequest.self, from: "{}")
    #expect(request.date == nil)
    #expect(request == DailyBriefRequest(date: nil))
  }

  @Test func test_weeklyBriefRequest_absentIsoWeek() throws {
    let request = try roundTrip(WeeklyBriefRequest.self, from: "{}")
    #expect(request.isoWeek == nil)
    #expect(request == WeeklyBriefRequest(isoWeek: nil))
  }
}
