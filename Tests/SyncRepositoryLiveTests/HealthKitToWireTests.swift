import DomainModels
import Foundation
import HealthKitClient
import WireModels
import XCTest

@testable import SyncRepositoryLive

final class HealthKitToWireTests: XCTestCase {
  func test_wireHealthRecord_mapsAllFields() {
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
    XCTAssertEqual(wire.uuid, "u1")
    XCTAssertEqual(wire.type, WireEnum(.heartRate))
    XCTAssertEqual(wire.start, payload.start)
    XCTAssertEqual(wire.end, payload.end)
    XCTAssertEqual(wire.value, 62)
    XCTAssertEqual(wire.unit, "count/min")
    XCTAssertEqual(wire.category, "resting")
    XCTAssertEqual(wire.source, "Watch")
    XCTAssertEqual(wire.metadata, .object(["motion": .string("still")]))
  }

  func test_wireHealthRecord_nilOptionals() {
    let payload = HealthRecordPayload(
      uuid: "u2", type: .stepCount, start: Date(timeIntervalSince1970: 1), end: Date(timeIntervalSince1970: 2)
    )
    let wire = wireHealthRecord(payload)
    XCTAssertNil(wire.value)
    XCTAssertNil(wire.unit)
    XCTAssertNil(wire.metadata)
  }

  func test_wireWorkout_mapsStatsAndOptionals() {
    let payload = WorkoutPayload(
      uuid: "w1",
      type: "running",
      start: Date(timeIntervalSince1970: 10),
      end: Date(timeIntervalSince1970: 20),
      durationS: 600,
      distanceM: 2500,
      activeEnergyKcal: 300,
      effortScore: 7,
      zoneMinutes: ["z2": 8.5],
      statistics: [WorkoutStatPayload(type: "heart_rate", value: 150, unit: "count/min")]
    )
    let wire = wireWorkout(payload)
    XCTAssertEqual(wire.uuid, "w1")
    XCTAssertEqual(wire.type, "running")
    XCTAssertEqual(wire.durationS, 600)
    XCTAssertEqual(wire.distanceM, 2500)
    XCTAssertEqual(wire.activeEnergyKcal, 300)
    XCTAssertEqual(wire.effortScore, 7)
    XCTAssertEqual(wire.zoneMinutes, ["z2": 8.5])
    XCTAssertEqual(wire.statistics, [WorkoutStat(type: "heart_rate", value: 150, unit: "count/min")])
  }

  func test_wireActivitySummary_mapsRingFields() {
    let payload = ActivitySummaryPayload(
      date: Date(timeIntervalSince1970: 100), activeEnergyKcal: 500, exerciseMinutes: 30, standHours: 12, steps: 8000
    )
    let wire = wireActivitySummary(payload)
    XCTAssertEqual(wire.date, WireCalendarDate(payload.date))
    XCTAssertEqual(wire.activeEnergyKcal, 500)
    XCTAssertEqual(wire.exerciseMinutes, 30)
    XCTAssertEqual(wire.standHours, 12)
    XCTAssertEqual(wire.steps, 8000)
  }

  func test_wireDailyCheckin_maps() {
    let checkIn = DomainModels.CheckIn(
      date: Date(timeIntervalSince1970: 100), giSymptoms: true, kneePain: 4, illness: false
    )
    let wire = wireDailyCheckin(checkIn)
    XCTAssertEqual(wire.date, WireCalendarDate(checkIn.date))
    XCTAssertTrue(wire.giSymptoms)
    XCTAssertEqual(wire.kneePain, 4)
    XCTAssertFalse(wire.illness)
  }

  func test_wireStrengthTest_maps() {
    let test = DomainModels.StrengthTest(date: Date(timeIntervalSince1970: 100), maxPushups: 35, maxPullups: 10)
    let wire = wireStrengthTest(test)
    XCTAssertEqual(wire.date, WireCalendarDate(test.date))
    XCTAssertEqual(wire.maxPushups, 35)
    XCTAssertEqual(wire.maxPullups, 10)
  }

  func test_buildSyncRequest_emptySet_isMinimalValidRequest() throws {
    let request = buildSyncRequest(samples: HealthSampleSet(), checkin: nil, strengthTest: nil)
    XCTAssertTrue(request.records.isEmpty)
    XCTAssertTrue(request.workouts.isEmpty)
    XCTAssertTrue(request.activitySummary.isEmpty)
    XCTAssertNil(request.checkin)
    XCTAssertNil(request.strengthTest)

    // Encodes to a server-valid body and round-trips.
    let data = try WireCoder.encoder.encode(request)
    let decoded = try WireCoder.decoder.decode(SyncRequest.self, from: data)
    XCTAssertEqual(decoded, request)
  }
}
