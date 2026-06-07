#if canImport(HealthKit)
  import Foundation
  import HealthKit
  import HealthKitClient

  /// Read everything newer than `since` across records, workouts, and activity. Real implementation
  /// (the HK query paths + payload mapping) lands in TASK-004; this placeholder lets TASK-003's
  /// authorization path compile.
  func liveDeltaSamples(store _: HKHealthStore, since _: Date) async throws -> HealthSampleSet {
    .empty
  }
#endif
