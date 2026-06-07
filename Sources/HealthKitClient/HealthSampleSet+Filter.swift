import Foundation

public extension HealthSampleSet {
  /// Keep only samples strictly newer than `anchor` — records/workouts by `start`, activity by its
  /// day `date`. This is the client-side anchor contract; `HealthKitClientLive` pushes the same
  /// "newer than the anchor" semantics into each HK query predicate, so live and test agree.
  func filtered(after anchor: Date) -> HealthSampleSet {
    HealthSampleSet(
      records: records.filter { $0.start > anchor },
      workouts: workouts.filter { $0.start > anchor },
      activity: activity.filter { $0.date > anchor }
    )
  }
}
