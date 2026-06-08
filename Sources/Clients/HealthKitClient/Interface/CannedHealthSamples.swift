import Foundation

/// Deterministic canned HealthKit data for `testValue`/`previewValue` — **interface-local**, no
/// `SampleData` import (DECISIONS #3 avoids the structural `HealthKitClient ↔ SampleData` cycle; the
/// richer SampleData HK factory is deferred to Epic 4.3). Timestamps are fixed (no wall clock) and
/// span the anchor, so anchor-filtering is testable.
enum CannedHealthSamples {
  /// A known anchor instant — samples are placed before and after it.
  static let healthAnchorFixture = Date(timeIntervalSinceReferenceDate: 770_000_000)

  private static let afterAnchor = Date(timeIntervalSinceReferenceDate: 770_086_400) // +1 day
  private static let beforeAnchor = Date(timeIntervalSinceReferenceDate: 769_913_600) // −1 day

  /// The full canned set (records/workouts/activity, some before and some after the anchor).
  static func cannedSampleSet() -> HealthSampleSet {
    HealthSampleSet(
      records: [
        HealthRecordPayload(
          uuid: "rec-hr", type: .heartRate, start: afterAnchor, end: afterAnchor,
          value: 142, unit: "count/min", source: "Apple Watch"
        ),
        HealthRecordPayload(
          uuid: "rec-protein", type: .dietaryProtein, start: afterAnchor, end: afterAnchor,
          value: 30, unit: "g", source: "MyFitnessPal"
        ),
        // Before the anchor — excluded by `filtered(after: healthAnchorFixture)`.
        HealthRecordPayload(
          uuid: "rec-steps", type: .stepCount, start: beforeAnchor, end: beforeAnchor,
          value: 8000, unit: "count", source: "iPhone"
        ),
      ],
      workouts: [
        WorkoutPayload(
          uuid: "wk-run", type: "HKWorkoutActivityTypeRunning", start: afterAnchor, end: afterAnchor,
          durationS: 2700, distanceM: 8000, activeEnergyKcal: 540, effortScore: 7,
          statistics: [WorkoutStatPayload(type: "heartRate", value: 152, unit: "count/min")]
        ),
      ],
      activity: [
        ActivitySummaryPayload(
          date: afterAnchor, activeEnergyKcal: 720, exerciseMinutes: 52, standHours: 11, steps: 9000
        ),
      ]
    )
  }

  /// All categories `.sharingAuthorized` — the canned status for the test value.
  static func authorizationStatusAllAuthorized() -> [HealthDataCategory: HealthAuthorizationStatus] {
    Dictionary(uniqueKeysWithValues: HealthDataCategory.allCases.map { ($0, .sharingAuthorized) })
  }
}
