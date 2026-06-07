import Foundation
@testable import HealthKitClient
import WireModels
import XCTest

final class HealthKitClientTestValueTests: XCTestCase {
  func test_testValue_isAvailableAndAllAuthorized() {
    let client = HealthKitClient.testValue
    XCTAssertTrue(client.isHealthDataAvailable())
    let status = client.authorizationStatus()
    XCTAssertEqual(status.count, HealthDataCategory.allCases.count)
    XCTAssertTrue(status.values.allSatisfy { $0 == .sharingAuthorized })
  }

  func test_deltaSamples_distantPast_returnsAllCannedSamples() async throws {
    let set = try await HealthKitClient.testValue.deltaSamples(.distantPast)
    XCTAssertEqual(set.records.count, 3)
    XCTAssertEqual(set.workouts.count, 1)
    XCTAssertEqual(set.activity.count, 1)
    // The canned workout carries an RPE and a stat (Epic 4.3 maps these to the wire shape).
    XCTAssertEqual(set.workouts.first?.effortScore, 7)
    XCTAssertEqual(set.workouts.first?.statistics.count, 1)
  }

  func test_filteredAfter_isInclusiveAtTheBoundary() {
    // The filter must agree with the live `predicateForSamples(withStart:)`, which is inclusive of
    // the start bound (round-1 review #2): a sample exactly at the anchor is kept.
    let anchor = Date(timeIntervalSinceReferenceDate: 1000)
    let set = HealthSampleSet(
      records: [HealthRecordPayload(uuid: "r", type: .heartRate, start: anchor, end: anchor)],
      activity: [
        ActivitySummaryPayload(date: anchor, activeEnergyKcal: 1, exerciseMinutes: 1, standHours: 1),
      ]
    )
    XCTAssertEqual(set.filtered(after: anchor).records.count, 1)
    XCTAssertEqual(set.filtered(after: anchor).activity.count, 1)
    // Strictly after the sample → excluded.
    XCTAssertTrue(set.filtered(after: anchor.addingTimeInterval(1)).records.isEmpty)
  }

  func test_deltaSamples_honoursAnchor_excludesBeforeAnchor() async throws {
    let set = try await HealthKitClient.testValue.deltaSamples(CannedHealthSamples.healthAnchorFixture)
    // Only the after-anchor samples survive (the before-anchor step_count record is excluded).
    XCTAssertEqual(set.records.count, 2)
    XCTAssertFalse(set.records.contains { $0.type == .stepCount })
    XCTAssertTrue(set.records.contains { $0.type == .heartRate })
    XCTAssertEqual(set.workouts.count, 1)
    XCTAssertEqual(set.activity.count, 1)
  }
}
