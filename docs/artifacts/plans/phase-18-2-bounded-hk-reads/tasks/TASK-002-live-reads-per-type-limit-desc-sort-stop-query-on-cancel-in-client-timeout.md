# TASK-002: Live reads: per-type limit + DESC sort, stop(query) on cancel, in-client timeout

Depends on: TASK-001
Suggested commit: `fix(healthkit): stop HK queries on cancel/timeout; bound rows per type`

## Goal

The live delta read honors its bounds: every `HKQuery` is limited, observes task
cancellation by calling `HKHealthStore.stop(query)`, and the whole read races an in-client
timeout that stops (not abandons) in-flight queries.

## Files

- `Sources/Clients/HealthKitClient/Live/HKDeltaReads.swift` —
  - `runRecordQuery`/`readWorkouts`: `limit: bounds.limitPerType`, `sortDescriptors:
    [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]` — DESC so a
    truncated read drops the OLDEST samples (PLAN.md Decision; never new-data loss).
  - Wrap each continuation in `withTaskCancellationHandler` driven by a LINEARIZABLE query
    lifecycle (validation round-2 #1 + round-3 #1 — a bare once-guard admits both a
    late-callback-claims-success race and a cancel-before-registration orphan): a
    lock-synchronized `QueryLifecycle` in the `HealthKitClient` **Interface** target
    (generic over a `StoppableQuery` handle protocol; no HealthKit import) with states
    `idle → registered(handle) → finished(result | cancelled)` and rules:
    - `register(handle)` AFTER cancellation → the handle is NEVER executed (register
      returns `.alreadyCancelled`; the caller resumes with `CancellationError` without
      calling `execute`);
    - `cancel()` after registration → records `CancellationError` FIRST, then stops the
      registered handle EXACTLY once;
    - result callback after cancellation → dropped (cannot claim success, not even empty);
    - every path resumes the continuation exactly once.
    The live code conforms `HKQuery`+store to `StoppableQuery` (`stop = store.stop(query)`)
    and registers BEFORE `execute`. Applies to record, workout, AND activity queries
    (`HKActivitySummaryQuery` has no limit parameter but is equally cancellation-deaf).
  - The timeout race is a host-testable coordinator, not inline task-group code (round-3
    #2): `BoundedReadCoordinator` (Interface target) takes a clock, a timeout, and N async
    read thunks over `QueryLifecycle`s; on timeout it cancels/stops every registered
    lifecycle and throws `HealthKitReadError.timedOut`. `liveDeltaSamples` becomes a thin
    assembly: build specs → lifecycles → coordinator.run. Deterministic host tests with fake
    `StoppableQuery` handles + `TestClock`: advance past timeout → `.timedOut` thrown, every
    in-flight handle stopped exactly once; cancel before registration → thunk never
    executes; cancel-vs-callback orderings from round-2 #1.
  - `liveDeltaSamples(box:bounds:)`: race the three reads against
    `clock.sleep(for: bounds.timeout)` in a `withThrowingTaskGroup` — on timeout cancel the
    group (→ handlers `stop()` every in-flight query) and throw
    `HealthKitReadError.timedOut`; on completion cancel the sleeper. Resolve the clock via
    `@Dependency(\.continuousClock)` (TestClock-able from repo tests through a stub client;
    the live race itself is exercised structurally).
  - One `@Dependency(\.log)` line at `.app` level when queries are stopped
    (`"HK read cancelled/timed out — stopped <n> in-flight queries"`) — the epic's
    show-it-stopping instrumentation.
- `Package.swift` — `HealthKitClientLive` currently depends only on
  HealthKitClient/WireModels/Dependencies; `DependencyValues.log` lives in the `LogClient`
  module. Add `LogClient` to the target's dependencies + `import LogClient` in
  `HKDeltaReads.swift` (validation round-1 #2).
- `Sources/Clients/HealthKitClient/Live/HealthKitClientLive.swift` — forward `bounds`
  (signature already threaded in TASK-001).

## Acceptance

- [ ] No `HKObjectQueryNoLimit` remains in the package (grep).
- [ ] Every `execute(query)` site is paired with a cancellation handler that calls
  `stop(query)` and a once-guarded resume (review-verifiable structure; no orphaned
  continuation on any path).
- [ ] Timeout path throws `HealthKitReadError.timedOut` (not `SyncError`, not a hang) and
  cancels the group.
- [ ] `make test` + `make lint` green; the `#if canImport(HealthKit)` module still compiles
  for the non-HK host arm.
- [ ] The iOS arm actually compiles (round-1 #3, command corrected round-2 #2 — the
  CoachKit-Package scheme lives in `.swiftpm/xcode/package.xcworkspace` and does NOT list
  `HealthKitClientTests`, so it is not a valid gate for this target): build the app scheme
  for the simulator, which links `HealthKitClientLive` —
  `xcodebuild build -project CoachApp.xcodeproj -scheme CoachApp -destination
  'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'` (the 18.1-proven invocation) — and
  require `HKDeltaReads.swift` in the compile transcript.
- [ ] `QueryLifecycle`/`BoundedReadCoordinator` pinned by deterministic host tests with fake
  handles + TestClock: cancel-then-callback → `CancellationError` (result dropped);
  callback-then-cancel → success kept; cancel BEFORE registration → handle never executed;
  timeout → `.timedOut` + every registered handle stopped exactly once; every path exactly
  one resume (round-2 #1, round-3 #1, round-3 #2).

Evidence: green host test/lint output + the iOS sim build transcript showing
HKDeltaReads.swift compiled + a grep transcript showing `NoLimit` gone and `stop(` present
per query site; the runtime log-line demonstration lands in TASK-004's sim run
(cancel mid-sync).

## Steps

### RED
- [ ] No new unit tests possible for live HK internals (constraint: no host-only HK tests);
  treat compile + the TASK-003 stub-client tests as the executable gate. Write the TASK-003
  bounds-capture test FIRST if convenient.

### GREEN
- [ ] Implement limits, sort, cancellation handlers, timeout race, log line.

### REFACTOR
- [ ] Extract the once-guarded continuation+stop wrapper as a small file-local helper so the
  three query kinds share one audited implementation; keep the file under the 400-line cap.

## Notes

`readActivity` resolves `@Dependency(\.calendar)/(\.date.now)` inside the function today —
keep that pattern when adding `\.continuousClock`/`\.log` (resolve at entry, snapshot into
Sendable locals before the `@Sendable` callbacks). Swallow-to-empty per-category error
behaviour is unchanged: cancellation/timeout is the ONLY whole-read failure.
