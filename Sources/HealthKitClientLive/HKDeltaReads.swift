#if canImport(HealthKit)
  import Foundation
  import HealthKit
  import HealthKitClient

  /// Read everything newer than `since` across records, workouts, and activity, mapping each HK sample
  /// to its payload (tagged with the wire `RecordType`). A denied/empty/failing category contributes an
  /// **empty slice, never an error** (PRD §7.1/§8.5): every query swallows its error to `[]`.
  ///
  /// The `@unchecked Sendable` `box` and the `Date` anchor are the only values that cross the
  /// concurrency boundaries (both Sendable); each query builds its own `NSPredicate` locally and maps
  /// the non-`Sendable` HK samples to `Sendable` payloads inside its callback, so nothing non-Sendable
  /// escapes a task.
  func liveDeltaSamples(box: HealthStoreBox, since: Date) async throws -> HealthSampleSet {
    guard HKHealthStore.isHealthDataAvailable() else { return .empty }

    async let records = readRecords(box: box, since: since)
    async let workouts = readWorkouts(box: box, since: since)
    async let activity = readActivity(box: box, since: since)

    return await HealthSampleSet(records: records, workouts: workouts, activity: activity)
  }

  private func samplePredicate(since: Date) -> NSPredicate {
    HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
  }

  private func readRecords(box: HealthStoreBox, since: Date) async -> [HealthRecordPayload] {
    await withTaskGroup(of: [HealthRecordPayload].self) { group in
      for spec in HKSampleMapping.recordQuerySpecs {
        group.addTask { await runRecordQuery(box: box, spec: spec, since: since) }
      }
      var all: [HealthRecordPayload] = []
      for await slice in group {
        all.append(contentsOf: slice)
      }
      return all
    }
  }

  private func runRecordQuery(
    box: HealthStoreBox, spec: RecordQuerySpec, since: Date
  ) async -> [HealthRecordPayload] {
    await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: spec.sampleType,
        predicate: samplePredicate(since: since),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, _ in
        // Map inside the callback so non-Sendable HK samples never cross to the awaiting task.
        continuation.resume(returning: (samples ?? []).map { HKSampleMapping.recordPayload(from: $0, spec: spec) })
      }
      box.store.execute(query)
    }
  }

  private func readWorkouts(box: HealthStoreBox, since: Date) async -> [WorkoutPayload] {
    await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: HKObjectType.workoutType(),
        predicate: samplePredicate(since: since),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, _ in
        let payloads = (samples ?? [])
          .compactMap { ($0 as? HKWorkout).map(HKSampleMapping.workoutPayload) }
        continuation.resume(returning: payloads)
      }
      box.store.execute(query)
    }
  }

  private func readActivity(box: HealthStoreBox, since: Date) async -> [ActivitySummaryPayload] {
    let calendar: Calendar = {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .current
      return calendar
    }()
    let units: Set<Calendar.Component> = [.year, .month, .day]
    let start = calendar.dateComponents(units, from: since)
    let end = calendar.dateComponents(units, from: Date())
    let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: start, end: end)

    return await withCheckedContinuation { continuation in
      let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
        let payloads = (summaries ?? [])
          .map { HKSampleMapping.activityPayload(from: $0, calendar: calendar) }
        continuation.resume(returning: payloads)
      }
      box.store.execute(query)
    }
  }
#endif
