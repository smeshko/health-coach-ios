import DomainModels
import Foundation
import HealthKitClient
import Testing
import WireModels

@testable import SyncRepositoryLive

struct HealthKitToWireTests {
  @Test func test_wireHealthRecord_mapsAllFields() {
    let payload = HealthRecordPayload(
      uuid: "u1",
      type: .heartRate,
      start: Date(timeIntervalSince1970: 1),
      end: Date(timeIntervalSince1970: 2),
      value: 62,
      unit: "count/min",
      category: "resting",
      source: "Watch",
      metadata: ["motion": "still"]
    )
    let wire = wireHealthRecord(payload)
    #expect(wire.uuid == "u1")
    #expect(wire.type == WireEnum(.heartRate))
    #expect(wire.start == payload.start)
    #expect(wire.end == payload.end)
    #expect(wire.value == 62)
    #expect(wire.unit == "count/min")
    #expect(wire.category == "resting")
    #expect(wire.source == "Watch")
    #expect(wire.metadata == ["motion": "still"])
  }

  @Test func test_wireHealthRecord_nilOptionals() {
    let payload = HealthRecordPayload(
      uuid: "u2", type: .stepCount, start: Date(timeIntervalSince1970: 1), end: Date(timeIntervalSince1970: 2)
    )
    let wire = wireHealthRecord(payload)
    #expect(wire.value == nil)
    #expect(wire.unit == nil)
    #expect(wire.metadata == nil)
  }

  @Test func test_wireWorkout_mapsOptionals() {
    let payload = WorkoutPayload(
      uuid: "w1",
      type: "running",
      start: Date(timeIntervalSince1970: 10),
      end: Date(timeIntervalSince1970: 20),
      durationS: 600,
      distanceM: 2500,
      activeEnergyKcal: 300,
      effortScore: 7
    )
    let wire = wireWorkout(payload)
    #expect(wire.uuid == "w1")
    #expect(wire.type == "running")
    #expect(wire.durationS == 600)
    #expect(wire.distanceM == 2500)
    #expect(wire.activeEnergyKcal == 300)
    #expect(wire.effortScore == 7)
  }

  @Test func test_wireActivitySummary_mapsRingFields() {
    let payload = ActivitySummaryPayload(
      date: Date(timeIntervalSince1970: 100), activeEnergyKcal: 500, exerciseMinutes: 30, standHours: 12, steps: 8000
    )
    let wire = wireActivitySummary(payload)
    #expect(wire.date == WireCalendarDate(payload.date))
    #expect(wire.activeEnergyKcal == 500)
    #expect(wire.exerciseMinutes == 30)
    #expect(wire.standHours == 12)
    #expect(wire.steps == 8000)
  }

  @Test func test_wireDailyCheckin_maps() {
    let checkIn = DomainModels.CheckIn(
      date: Date(timeIntervalSince1970: 100), giSymptoms: true, kneePain: 4, illness: false
    )
    let wire = wireDailyCheckin(checkIn)
    #expect(wire.date == WireCalendarDate(checkIn.date))
    #expect(wire.giSymptoms)
    #expect(wire.kneePain == 4)
    #expect(!wire.illness)
  }

  @Test func test_wireStrengthTest_maps() {
    let test = DomainModels.StrengthTest(date: Date(timeIntervalSince1970: 100), maxPushups: 35, maxPullups: 10)
    let wire = wireStrengthTest(test)
    #expect(wire.date == WireCalendarDate(test.date))
    #expect(wire.maxPushups == 35)
    #expect(wire.maxPullups == 10)
  }

  @Test func test_buildSyncRequest_emptySet_isMinimalValidRequest() throws {
    let request = buildSyncRequest(samples: HealthSampleSet(), checkin: nil, strengthTest: nil)
    #expect(request.records.isEmpty)
    #expect(request.workouts.isEmpty)
    #expect(request.activitySummary.isEmpty)
    #expect(request.checkin == nil)
    #expect(request.strengthTest == nil)

    // Encodes to a server-valid body: empty arrays, the two optionals omitted.
    let data = try WireCoder.encoder.encode(request)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect((object["records"] as? [Any])?.isEmpty == true)
    #expect((object["workouts"] as? [Any])?.isEmpty == true)
    #expect((object["activitySummary"] as? [Any])?.isEmpty == true)
    #expect(object["checkin"] == nil)
    #expect(object["strengthTest"] == nil)
  }
}
