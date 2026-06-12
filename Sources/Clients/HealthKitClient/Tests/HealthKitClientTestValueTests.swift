import Foundation
import Testing
import WireModels

@testable import HealthKitClient

struct HealthKitClientTestValueTests {
  @Test func test_testValue_isAvailableAndAllAuthorized() {
    let client = HealthKitClient.testValue
    #expect(client.isHealthDataAvailable())
    let status = client.authorizationStatus()
    #expect(status.count == HealthDataCategory.allCases.count)
    #expect(status.values.allSatisfy { $0 == .sharingAuthorized })
  }

  @Test func test_deltaSamples_distantPast_returnsAllCannedSamples() async throws {
    let set = try await HealthKitClient.testValue.deltaSamples(.distantPast)
    #expect(set.records.count == 3)
    #expect(set.workouts.count == 1)
    #expect(set.activity.count == 1)
    // The canned workout carries an RPE (Epic 4.3 maps these to the wire shape).
    #expect(set.workouts.first?.effortScore == 7)
  }

  @Test func test_filteredAfter_isInclusiveAtTheBoundary() {
    // The filter must agree with the live `predicateForSamples(withStart:)`, which is inclusive of
    // the start bound (round-1 review #2): a sample exactly at the anchor is kept.
    let anchor = Date(timeIntervalSinceReferenceDate: 1000)
    let set = HealthSampleSet(
      records: [HealthRecordPayload(uuid: "r", type: .heartRate, start: anchor, end: anchor)],
      activity: [
        ActivitySummaryPayload(date: anchor, activeEnergyKcal: 1, exerciseMinutes: 1, standHours: 1),
      ]
    )
    #expect(set.filtered(after: anchor).records.count == 1)
    #expect(set.filtered(after: anchor).activity.count == 1)
    // Strictly after the sample → excluded.
    #expect(set.filtered(after: anchor.addingTimeInterval(1)).records.isEmpty)
  }

  @Test func test_deltaSamples_honoursAnchor_excludesBeforeAnchor() async throws {
    let set = try await HealthKitClient.testValue.deltaSamples(CannedHealthSamples.healthAnchorFixture)
    // Only the after-anchor samples survive (the before-anchor step_count record is excluded).
    #expect(set.records.count == 2)
    #expect(!set.records.contains { $0.type == .stepCount })
    #expect(set.records.contains { $0.type == .heartRate })
    #expect(set.workouts.count == 1)
    #expect(set.activity.count == 1)
  }
}
