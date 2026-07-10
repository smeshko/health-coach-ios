#if canImport(HealthKit)
  import Dependencies
  import Foundation
  import HealthKit
  import HealthKitClient
  import LogClient

  /// Read everything newer than `bounds.since` across records, workouts, and activity, mapping each
  /// HK sample to its payload (tagged with the wire `RecordType`). A denied/empty/failing category
  /// contributes an **empty slice, never an error** (PRD §7.1/§8.5): every query swallows its error
  /// to `[]`. The whole read is bounded (Phase 18.2): every sample query carries
  /// `bounds.limitPerType` with a newest-first sort (truncation drops the OLDEST samples — the
  /// backfill-floor philosophy, never new-data loss), every query observes cancellation by stopping
  /// itself via its `QueryLifecycle`, and the read races `bounds.timeout` in
  /// `BoundedReadCoordinator` — timeout/cancellation stops (not abandons) the in-flight queries and
  /// throws `HealthKitReadError.timedOut`/`CancellationError`.
  ///
  /// The `@unchecked Sendable` `box` and the `HealthReadBounds` anchor are the only values that
  /// cross the concurrency boundaries (both Sendable); each query builds its own `NSPredicate`
  /// locally and maps the non-`Sendable` HK samples to `Sendable` payloads inside its callback, so
  /// nothing non-Sendable escapes a task.
  func liveDeltaSamples(box: HealthStoreBox, bounds: HealthReadBounds) async throws -> HealthSampleSet {
    guard HKHealthStore.isHealthDataAvailable() else { return .empty }
    @Dependency(\.continuousClock) var clock
    @Dependency(\.log) var log

    // Snapshot the resolved client into a plain value so the `@Sendable` instrumentation callback
    // captures a Sendable `LogClient`, not the `@Dependency` storage.
    let logClient = log
    // The per-workout effort-relationship queries are spawned only after the workouts query
    // delivers — the composite registry owns those dynamic children and joins the coordinator's
    // FIXED lifecycle array upfront, so timeout/cancellation reaches them too (TASK-004).
    let effortRegistry = ChildQueryRegistry()
    let reads = deltaReads(box: box, bounds: bounds, effortRegistry: effortRegistry)
    let slices = try await BoundedReadCoordinator.run(
      lifecycles: reads.map(\.lifecycle) + [effortRegistry],
      timeout: bounds.timeout,
      clock: clock,
      onQueriesStopped: { count in
        logClient.notice(
          "HK read cancelled/timed out — stopped \(count) in-flight queries", category: .app
        )
      },
      operations: reads.map(\.operation)
    )

    var set = HealthSampleSet.empty
    for slice in slices {
      switch slice {
      case .records(let payloads): set.records.append(contentsOf: payloads)
      case .workouts(let payloads): set.workouts.append(contentsOf: payloads)
      case .activity(let payloads): set.activity.append(contentsOf: payloads)
      }
    }
    return set
  }

  /// One category's contribution to the delta read — the common output the coordinator collects.
  private enum DeltaSlice: Sendable {
    case records([HealthRecordPayload])
    case workouts([WorkoutPayload])
    case activity([ActivitySummaryPayload])
  }

  /// A read operation paired with the lifecycle governing its single query, so the coordinator can
  /// stop the query when the operation's task no longer wants the answer.
  private struct DeltaRead: Sendable {
    let lifecycle: any QueryCancelling
    let operation: @Sendable () async throws -> DeltaSlice
  }

  /// Pairs a built `HKQuery` with the store that runs it so a `QueryLifecycle` can stop it in
  /// place. `@unchecked Sendable`: `HKHealthStore` is thread-safe for execute/stop, and the query
  /// reference is only ever handed to that store.
  private struct HKQueryHandle: StoppableQuery, @unchecked Sendable {
    let store: HKHealthStore
    let query: HKQuery

    func execute() { store.execute(query) }
    func stop() { store.stop(query) }
  }

  private func deltaReads(
    box: HealthStoreBox, bounds: HealthReadBounds, effortRegistry: ChildQueryRegistry
  ) -> [DeltaRead] {
    var reads: [DeltaRead] = HKSampleMapping.recordQuerySpecs.map { spec in
      let lifecycle = QueryLifecycle<HKQueryHandle, [HealthRecordPayload]>()
      return DeltaRead(lifecycle: lifecycle) {
        try await .records(runRecordQuery(box: box, spec: spec, bounds: bounds, lifecycle: lifecycle))
      }
    }
    let workouts = QueryLifecycle<HKQueryHandle, [WorkoutPayload]>()
    reads.append(
      DeltaRead(lifecycle: workouts) {
        try await .workouts(
          readWorkouts(box: box, bounds: bounds, lifecycle: workouts, effortRegistry: effortRegistry)
        )
      }
    )
    let activity = QueryLifecycle<HKQueryHandle, [ActivitySummaryPayload]>()
    reads.append(
      DeltaRead(lifecycle: activity) {
        try await .activity(readActivity(box: box, bounds: bounds, lifecycle: activity))
      }
    )
    return reads
  }

  private func samplePredicate(since: Date) -> NSPredicate {
    HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
  }

  /// Newest first, so a `limitPerType`-truncated read drops the OLDEST samples (PLAN.md Decision —
  /// matches the backfill-floor philosophy; ascending would silently skip the newest forever).
  private func newestFirst() -> NSSortDescriptor {
    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
  }

  private func runRecordQuery(
    box: HealthStoreBox,
    spec: RecordQuerySpec,
    bounds: HealthReadBounds,
    lifecycle: QueryLifecycle<HKQueryHandle, [HealthRecordPayload]>
  ) async throws -> [HealthRecordPayload] {
    try await lifecycle.run(
      makeHandle: {
        let query = HKSampleQuery(
          sampleType: spec.sampleType,
          predicate: samplePredicate(since: bounds.since),
          limit: bounds.limitPerType,
          sortDescriptors: [newestFirst()]
        ) { _, samples, _ in
          // Map inside the callback so non-Sendable HK samples never cross to the awaiting task; a
          // failed query finishes as `[]` (empty slice, never an error). A post-cancellation
          // callback is dropped by the lifecycle.
          lifecycle.finish((samples ?? []).map { HKSampleMapping.recordPayload(from: $0, spec: spec) })
        }
        return HKQueryHandle(store: box.store, query: query)
      },
      execute: { $0.execute() }
    )
  }

  private func readWorkouts(
    box: HealthStoreBox,
    bounds: HealthReadBounds,
    lifecycle: QueryLifecycle<HKQueryHandle, [WorkoutPayload]>,
    effortRegistry: ChildQueryRegistry
  ) async throws -> [WorkoutPayload] {
    var payloads = try await lifecycle.run(
      makeHandle: {
        let query = HKSampleQuery(
          sampleType: HKObjectType.workoutType(),
          predicate: samplePredicate(since: bounds.since),
          limit: bounds.limitPerType,
          sortDescriptors: [newestFirst()]
        ) { _, samples, _ in
          // Mapped with nil effort here; effort is resolved below via per-workout relationship
          // queries (only the workout's uuid — a Sendable value — crosses back out).
          let payloads = (samples ?? []).compactMap { sample in
            (sample as? HKWorkout).map { HKSampleMapping.workoutPayload(from: $0, effortScore: nil) }
          }
          lifecycle.finish(payloads)
        }
        return HKQueryHandle(store: box.store, query: query)
      },
      execute: { $0.execute() }
    )
    // Effort lives as related quantity samples (iOS 18+/macOS 15+); the package's iOS floor (26)
    // always satisfies the clause — the guard exists only for the macOS 14 host floor.
    guard #available(macOS 15.0, *) else { return payloads }
    for index in payloads.indices {
      guard let uuid = UUID(uuidString: payloads[index].uuid) else { continue }
      payloads[index].effortScore = try await readEffortScore(
        box: box, workoutUUID: uuid, registry: effortRegistry
      )
    }
    return payloads
  }

  /// Resolve one workout's effort score via `HKWorkoutEffortRelationshipQuery` (D2). The child
  /// lifecycle registers with the composite `registry` (already in the coordinator's array), so
  /// timeout/cancellation stops the dynamically spawned query — even one added after a stop. This
  /// is a long-running, caller-stopped query: the one-shot `finishStoppingHandle` stops it exactly
  /// once on its first delivery (a plain `finish` would leave it streaming forever). A
  /// failing/denied/empty relationship read degrades to `nil` effort for this workout — never an
  /// error for the whole read (empty-slice-not-error).
  @available(macOS 15.0, *)
  private func readEffortScore(
    box: HealthStoreBox,
    workoutUUID: UUID,
    registry: ChildQueryRegistry
  ) async throws -> Int? {
    let lifecycle = QueryLifecycle<HKQueryHandle, Int?>()
    registry.add(lifecycle)
    return try await lifecycle.run(
      makeHandle: {
        let query = HKWorkoutEffortRelationshipQuery(
          predicate: HKQuery.predicateForObject(with: workoutUUID),
          anchor: nil,
          options: .default
        ) { _, relationships, _, _ in
          // Classify inside the callback so non-Sendable HK samples never cross to the awaiting
          // task; a nil/error delivery reduces over [] → nil effort.
          lifecycle.finishStoppingHandle(relatedEffortScore(from: relationships ?? []))
        }
        return HKQueryHandle(store: box.store, query: query)
      },
      execute: { $0.execute() }
    )
  }

  /// Classify a workout's related effort samples — user-logged (`workoutEffortScore`) vs
  /// system-estimated (`estimatedWorkoutEffortScore`), both carried in the same relationship's
  /// `.samples` — and reduce them to the wire score via the pure preference seam.
  @available(macOS 15.0, *)
  private func relatedEffortScore(from relationships: [HKWorkoutEffortRelationship]) -> Int? {
    let unit = HKUnit.appleEffortScore()
    var userLogged: [(date: Date, value: Double)] = []
    var estimated: [(date: Date, value: Double)] = []
    for relationship in relationships {
      for sample in relationship.samples ?? [] {
        guard let quantitySample = sample as? HKQuantitySample,
              quantitySample.quantity.is(compatibleWith: unit)
        else { continue }
        let entry = (
          date: quantitySample.startDate,
          value: quantitySample.quantity.doubleValue(for: unit)
        )
        switch quantitySample.quantityType.identifier {
        case HKQuantityTypeIdentifier.workoutEffortScore.rawValue: userLogged.append(entry)
        case HKQuantityTypeIdentifier.estimatedWorkoutEffortScore.rawValue: estimated.append(entry)
        default: break
        }
      }
    }
    return HKSampleMapping.preferredEffortScore(userLogged: userLogged, estimated: estimated)
  }

  private func readActivity(
    box: HealthStoreBox,
    bounds: HealthReadBounds,
    lifecycle: QueryLifecycle<HKQueryHandle, [ActivitySummaryPayload]>
  ) async throws -> [ActivitySummaryPayload] {
    // Resolve the app's pinned frame (Europe/Sofia, installed at the composition root via
    // `useEuropeSofia()`) so activity-summary day buckets line up with the rest of the app's date
    // math rather than the device locale — and the injected clock for the `end` boundary.
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now

    // Review #2.2 + #3.1: `HKActivitySummaryQuery` has no `limit` parameter, so the WINDOW is the
    // bound — `activitySince` floors the start at `limitPerType - 1` days before now (the activity
    // predicate is inclusive at both day endpoints; summaries are one-per-day, so this enforces the
    // same per-type row cardinality as the sample queries; the `.distantPast` probe no longer
    // requests an unbounded range).
    let since = bounds.activitySince(now: now, calendar: calendar)

    // Activity-summary predicates require each `DateComponents` to carry its own calendar — the
    // components returned by `dateComponents(_:from:)` do **not** (HealthKit raises
    // `NSInvalidArgumentException: Date components require a calendar` otherwise). `.era` is
    // included per Apple's guidance so the day boundaries are unambiguous.
    let units: Set<Calendar.Component> = [.era, .year, .month, .day]
    var startComponents = calendar.dateComponents(units, from: since)
    startComponents.calendar = calendar
    var endComponents = calendar.dateComponents(units, from: now)
    endComponents.calendar = calendar
    // Immutable snapshots: `@Sendable` closures may not capture mutated `var`s.
    let start = startComponents
    let end = endComponents

    // Snapshot the resolved calendar into a plain value so the `@Sendable` query callback captures
    // a Sendable `Calendar`, not the `@Dependency` storage; the (non-Sendable) `NSPredicate` is
    // built from the Sendable components INSIDE `makeHandle` so it never crosses the boundary.
    // (The query is wrapped in the same lifecycle so cancellation/timeout stops it too.)
    let payloadCalendar = calendar
    return try await lifecycle.run(
      makeHandle: {
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: start, end: end)
        let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
          let payloads = (summaries ?? [])
            .map { HKSampleMapping.activityPayload(from: $0, calendar: payloadCalendar) }
          lifecycle.finish(payloads)
        }
        return HKQueryHandle(store: box.store, query: query)
      },
      execute: { $0.execute() }
    )
  }
#endif
