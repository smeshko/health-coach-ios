import Foundation
import Testing
import WireModels

@testable import HealthKitClient

/// Tests for `HealthSampleSet.filtered(after:)` — the anchor-boundary filter that `deltaSamples` applies
/// to exclude before-anchor samples. (Renamed from HealthKitClientTestValueTests in Phase 11.6 — the
/// testValue canned-data tests were deleted; the former test_deltaSamples_honoursAnchor folded into the
/// boundary test below by adding a workout at the anchor instant so the workouts filter line keeps its
/// only direct coverage — audit MERGE.)
struct HealthSampleSetFilterTests {
  @Test func test_filteredAfter_isInclusiveAtTheBoundary() {
    // The filter must agree with the live `predicateForSamples(withStart:)`, which is inclusive of
    // the start bound (round-1 review #2): a sample exactly at the anchor is kept; one strictly before
    // is dropped; one strictly after the cutoff is dropped.
    let anchor = Date(timeIntervalSinceReferenceDate: 1000)
    let before = anchor.addingTimeInterval(-1)
    let set = HealthSampleSet(
      records: [
        HealthRecordPayload(uuid: "at", type: .heartRate, start: anchor, end: anchor),
        HealthRecordPayload(uuid: "before", type: .stepCount, start: before, end: before),
      ],
      workouts: [
        WorkoutPayload(uuid: "wk", type: "running", start: anchor, end: anchor, durationS: 100),
      ],
      activity: [
        ActivitySummaryPayload(date: anchor, activeEnergyKcal: 1, exerciseMinutes: 1, standHours: 1),
      ]
    )

    let kept = set.filtered(after: anchor)
    #expect(kept.records.count == 1, "the at-anchor record is kept, the before-anchor one excluded")
    #expect(kept.records.contains { $0.type == .heartRate })
    #expect(!kept.records.contains { $0.type == .stepCount })
    #expect(kept.workouts.count == 1, "a workout exactly at the anchor is kept (inclusive bound)")
    #expect(kept.activity.count == 1)

    // Strictly after the samples → everything excluded.
    #expect(set.filtered(after: anchor.addingTimeInterval(1)).records.isEmpty)
    #expect(set.filtered(after: anchor.addingTimeInterval(1)).workouts.isEmpty)
  }
}
