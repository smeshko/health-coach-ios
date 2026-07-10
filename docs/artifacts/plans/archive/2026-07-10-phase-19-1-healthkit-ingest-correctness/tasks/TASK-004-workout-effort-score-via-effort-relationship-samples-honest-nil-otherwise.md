# TASK-004: Workout effort score via effort-relationship samples (honest nil otherwise)

Depends on: TASK-002
Suggested commit: `fix(healthkit): source workout effort from effort-relationship samples instead of a nonexistent metadata key`

## Goal

`effortScore` is populated from the workout's related `workoutEffortScore` samples
(preferring user-logged over system-estimated) when the platform provides them, and is
honestly `nil` otherwise — the read of the nonexistent `metadata["HKWorkoutEffortScore"]`
key is deleted.

## Files

- `Sources/Clients/HealthKitClient/Live/HKSampleMapping.swift` — delete the metadata read;
  `workoutPayload` gains an `effortScore: Int?` parameter (resolved by the caller). Add a
  pure preference seam over **timestamped** samples (validation round-1 #4):
  `static func preferredEffortScore(userLogged: [(date: Date, value: Double)], estimated:
  [(date: Date, value: Double)]) -> Int?` — any user-logged beats any estimated;
  newest-by-date wins within a class; rounded to Int. (Bare `[Double]` cannot implement
  "latest wins".)
- `Sources/Clients/HealthKitClient/Interface/` (`QueryLifecycle.swift` vicinity) — a
  composite child-query registry (validation round-1 #2): a `QueryCancelling`
  implementation that owns dynamically spawned child lifecycles — children are added as
  the relationship queries are created, `stop()`/cancellation forwards to every live
  child, children added *after* a stop are stopped immediately (no escape window). The
  registry is placed in the coordinator's lifecycle array **upfront**, so the fixed-array
  shape of `BoundedReadCoordinator` is unchanged.
- Exact stopped-count accounting (validation round-2 #2, refined by round-3 #1): the
  coordinator's `onQueriesStopped` count is computed from a per-lifecycle Boolean
  (`handleWasStopped`), so a registry that stopped N children would report ≤1. Extend the
  counting contract so the registry contributes its exact stopped-child count — e.g.
  `QueryCancelling` gains a `stoppedHandleCount: Int` (existing lifecycles: 0/1 from the
  Boolean; registry: number of stopped children) and `BoundedReadCoordinator` sums it.
  **The count means "in-flight queries stopped by timeout/cancellation cleanup" — a
  child stopped normally on first delivery (the one-shot success path) must NOT be
  counted.** The registry therefore tracks failure/cancellation stops separately from
  normal one-shot stops and exposes only the former. Tests assert the reported count
  includes every dynamic child on both timeout and caller-cancellation paths, plus a
  mixed-outcome case: one child completes (stopped normally), then a remaining child
  times out / is cancelled — the emitted count includes only the still-in-flight child.
- One-shot success-path stop (validation round-2 #3): `HKWorkoutEffortRelationshipQuery`
  is a long-running, caller-stopped query, and `QueryLifecycle.finish` only drops later
  callbacks — it does **not** stop the handle (coordinator success tests expect zero
  stops for one-shot sample queries). The relationship queries therefore use a one-shot
  wrapper/mode that calls `stop()` on the concrete query exactly once upon its first
  delivery while preserving the delivered result — without changing the zero-stop success
  semantics of the existing sample queries.
- `Sources/Clients/HealthKitClient/Live/HKDeltaReads.swift` — inside the workouts
  operation, after the workouts query finishes, resolve effort per workout via
  `HKWorkoutEffortRelationshipQuery` with `HKQuery.predicateForObject(with: UUID)` (the
  workout's uuid — no non-Sendable `HKWorkout` crosses a boundary), each child wrapped in
  `QueryLifecycle`/`HKQueryHandle` and registered with the composite registry; a
  failing/denied/empty relationship read degrades to `nil` effort for that workout
  (empty-slice-not-error), and each query is stopped after its first delivery.
- `Sources/Clients/HealthKitClient/Live/HKTypeCatalog.swift` — add
  `HKQuantityType(.workoutEffortScore)` and `HKQuantityType(.estimatedWorkoutEffortScore)`
  to `HealthDataCategory.workouts.hkObjectTypes` (read authorization).
- `Sources/Clients/HealthKitClient/Tests/HKEffortScoreTests.swift` (new) — pins
  `preferredEffortScore`: user-logged beats estimated regardless of dates; newest-by-date
  wins within a class given **unordered** inputs with distinct dates; empty → nil;
  rounding to Int.
- `Sources/Clients/HealthKitClient/Tests/` (new or existing lifecycle test file) —
  fake-handle registry tests (validation round-1 #2): registering N children then
  stopping the registry stops each child exactly once; a child added after the stop is
  stopped immediately; a post-cancellation delivery does not contribute a value (the
  existing `QueryLifecycle` drop-after-finish contract, exercised through the registry).
- `Sources/Clients/HealthKitClient/Tests/HKReadSetCoverageTests.swift` — add a **direct,
  unconditional** assert that both effort quantity types are members of
  `HKTypeCatalog.allReadTypes` (validation round-1 #5 — the recordQuerySpecs-based guard
  cannot catch their omission because effort types are not record query specs).

## Acceptance

- [ ] No read of `metadata["HKWorkoutEffortScore"]` remains.
- [ ] `preferredEffortScore` pinned over timestamped, unordered inputs: user-logged beats
  estimated; newest-by-date wins within a class; empty inputs → nil; values read in
  `HKUnit.appleEffortScore()` round to the wire Int.
- [ ] Direct membership test: `HKQuantityType(.workoutEffortScore)` and
  `HKQuantityType(.estimatedWorkoutEffortScore)` ∈ `HKTypeCatalog.allReadTypes`
  (unconditional — not gated on the record-specs coverage guard).
- [ ] Fake-handle tests prove the composite registry stops every dynamically spawned
  child exactly once on timeout/cancellation, stops late-added children immediately, and
  post-cancellation deliveries cannot contribute.
- [ ] The coordinator's stopped-query count includes every dynamic child (exact-count
  contract, asserted on timeout and caller-cancellation paths) — no Boolean
  underreporting — and counts ONLY failure/cancellation cleanup: a mixed-outcome test
  (one child stopped normally on delivery, another stopped by timeout/cancellation)
  reports exactly the still-in-flight child.
- [ ] A fake-handle test asserts the one-shot relationship wrapper stops its query
  exactly once on normal first delivery (success path), in addition to
  timeout/cancellation — while existing one-shot sample queries keep their zero-stop
  success semantics (existing coordinator tests unchanged).
- [ ] A relationship-read failure yields nil effort for that workout, never an error for
  the whole read.

Evidence: HealthKitClient test-suite output (preference + read-set + registry
cancellation tests green); grep output showing the metadata key gone.

## Steps

### RED
- [ ] Add `HKEffortScoreTests` (timestamped preference), the unconditional read-set
  membership assert, and the composite-registry fake-handle tests — all fail
  (function/types/registry absent).

### GREEN
- [ ] Catalog types, pure preference function, composite child registry in the Interface
  target, relationship-query wiring in `HKDeltaReads`, delete the metadata read.

### REFACTOR
- [ ] Keep `workoutPayload` a pure function (effort passed in) so TASK-002/003 tests stay
  store-free; confirm the whole HealthKitClient suite is green.

## Notes

- `HKWorkoutEffortRelationshipQuery` (iOS 18+; package floor iOS 26) delivers
  relationships whose `.samples` include both effort types — classify by the sample's
  quantity type identifier.
- Stop each relationship query after its first delivery (`QueryLifecycle.finish` already
  drops post-finish callbacks) — it's a has-more/anchored-style API.
- Depends on TASK-002 only to avoid merge friction in `workoutPayload`'s signature —
  do them in order.
