import Foundation

public extension HealthSampleSet {
  /// Keep only samples **at or after** `anchor` — records/workouts by `start`, activity by its day
  /// `date`. This matches `HealthKitClientLive`'s live `HKQuery.predicateForSamples(withStart:)`,
  /// which is **inclusive** of the start bound, so live and test agree at the boundary instant; a
  /// boundary sample re-read on the next sync is absorbed by the idempotent upsert (DECISIONS #2).
  func filtered(after anchor: Date) -> HealthSampleSet {
    HealthSampleSet(
      records: records.filter { $0.start >= anchor },
      workouts: workouts.filter { $0.start >= anchor },
      activity: activity.filter { $0.date >= anchor }
    )
  }
}
