# Research: HealthKit ingest correctness (Phase 19.1)

Curated findings from exploration, 2026-07-10. Sources: audit
`docs/artifacts/audits/AUDIT-2026-07-05.md` (Domain Correctness lens), code reads of the
HealthKitClient Live target and SyncRepository, backend contract in
`backend/app/api/schemas/sync.py` + `backend/app/services/daily_metrics_engine.py`.

## 1. Watermark / late-arriving samples (audit [High])

- Watermark storage: `SyncWatermarkRecord` (GRDB table `syncWatermark`, singleton id=1) —
  `anchor: String?` is the previous sync's `readInstant` serialized as
  `timeIntervalSince1970` (`SyncRepository+Live.swift` `anchorString`/`anchorDate`,
  ~lines 149–160). `backfillFloor = Date(timeIntervalSince1970: 1_779_483_600)`
  (2026-05-23 Sofia).
- `runSync` flow: read watermark → capture `readInstant = date.now` **before** the HK read
  → `healthKit.deltaSamples(.since(anchorDate(anchor)))` → POST `/sync` → on success only,
  save `anchor = anchorString(readInstant)`.
- The HK query (`HKDeltaReads.swift` `samplePredicate`) filters
  `HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)` —
  i.e. by **sample startDate**, not by when the sample landed in the store.
- Failure mode: overnight sleep (startDate ~23:00) transfers from the Watch after the
  ~07:00 sync; next sync's floor is 07:00 → the sample is excluded forever. Same for HRV,
  RHR, and backdated manual/dietary entries. These are the primary readiness inputs.
- Idempotency: on any failure the watermark is untouched and the same window is re-sent;
  the backend `_upsert` dedups by uuid → **re-sending samples is safe by design**.
- Existing tests to update: `SyncBoundedReadTests.test_sync_requestsBoundedRead_sinceAnchor_defaultLimitAndTimeout`
  asserts `bounds.since == anchor` exactly; `SyncOrchestrationTests` records `bounds.since`
  via `SyncStubs.sinceRecorder`.
- Volume sanity for a 48h lookback: Watch heart rate ≈ 300–700 samples/day ambient plus
  ~720/h in workouts → worst case low thousands per type, well under
  `limitPerType = 10000`; newest-first sort means even a truncated read drops the oldest
  (already-synced) rows first.

## 2. Workout type string (audit [Medium]/[High] contract drift)

- Live mapping (`HKSampleMapping.workoutPayload`, line ~95):
  `type: String(workout.workoutActivityType.rawValue)` → `"37"`, `"52"`, …
- Wire model `WireModels.Workout.type` is a free string; backend `sync.py Workout.type`
  is a free string; backend canonicalization
  (`daily_metrics_engine._canonical_activity_type`) strips the
  `HKWorkoutActivityType` prefix from seeded values and lowercases — a bare numeric string
  canonicalizes to itself and never matches
  `HARD_ACTIVITY_TYPES = {"boxing", "high_intensity_interval_training", "kickboxing",
  "martial_arts"}` or any other name-based classification.
- Fixtures on both sides use snake_case name strings: `"running"`, `"boxing"`,
  `"cycling"`, `"rowing"`, `"walking"`, `"high_intensity_interval_training"`. iOS test
  fixtures (`HealthKitToWireTests`, `HealthSampleSetFilterTests`) also use `"running"`.
- `HKWorkoutActivityType` is an @objc enum — no reflection of case names; an explicit
  mapping table is required. `@unknown default` must keep a deterministic fallback.

## 3. Distance (audit [Medium] (1))

- `workoutPayload` reads only
  `workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()`.
- HealthKit stores per-modality distance under distinct quantity types:
  `.distanceCycling`, `.distanceSwimming`, `.distanceRowing` (plus others the product
  doesn't classify). A workout carries statistics only for its own distance type, so
  "first non-nil across an ordered candidate list" is exact, not heuristic.

## 4. Effort score (audit [Medium] (2))

- `metadata["HKWorkoutEffortScore"]` is not a real HealthKit metadata key → effort is
  always nil today.
- Apple (iOS 18+, package floor iOS 26): effort lives as samples of
  `HKQuantityType(.workoutEffortScore)` (user-logged) and
  `HKQuantityType(.estimatedWorkoutEffortScore)` (system-estimated), associated to a
  workout; `HKWorkoutEffortRelationshipQuery` with
  `HKQuery.predicateForObject(with: UUID)` retrieves the related samples without holding
  the (non-Sendable) `HKWorkout` across a concurrency boundary. Unit:
  `HKUnit.appleEffortScore()`.
- Read authorization: those quantity types must be added to the read set —
  `HKTypeCatalog` / `HealthDataCategory.workouts.hkObjectTypes` is "the only place HK type
  identifiers live".
- Concurrency/bounding pattern to follow: every query is wrapped in
  `QueryLifecycle<HKQueryHandle, T>` and registered with `BoundedReadCoordinator` so
  timeout/cancellation stops it (Phase 18.2 machinery, `HKDeltaReads.swift`).

## 5. Test seams

- SyncRepository: bounds captured via stubbed `healthKitClient` closure +
  `LockIsolated`/`CallRecorder` (`SyncBoundedReadTests`, `SyncOrchestrationTests`); DB
  seeded in-memory via GRDB.
- HK Live target has **zero** tests (audit [High], "entire live on-device HealthKit read
  path"). Sim tests cannot exercise real HK stores; correctness logic must be extracted
  into pure functions (name mapping, distance-candidate selection, effort-sample
  preference) with the thin HK-touching shell left unexercised.
- Existing HK client test files: `HealthReadBoundsTests` (pure bounds math),
  `HKReadSetCoverageTests` (recordQuerySpecs ↔ wire RecordType coverage guard) — the
  latter may need the effort types exempted/accounted for if the guard is set-based.

## Useful Commands

```bash
make test-sim          # full package tests on the canonical sim (iPhone 17 Pro / OS 26.0)
make lint              # swiftlint over Sources (staging carries one pre-existing nesting violation)
```

## Uncertainty

- Whether `HKWorkoutEffortRelationshipQuery`'s handler delivers once or streams updates —
  resolved in implementation by stopping the query after the first delivery (the
  `QueryLifecycle.finish` pattern already drops post-cancellation callbacks).
- Whether constructed `HKWorkout` objects on the sim populate `statistics(for:)` — not
  relied on: tests pin the pure candidate-selection/mapping functions instead.

## References

- `docs/artifacts/audits/AUDIT-2026-07-05.md` — findings quoted in PLAN Risks/Goal.
- Apple: HKWorkoutEffortRelationshipQuery, workoutEffortScore /
  estimatedWorkoutEffortScore quantity types (iOS 18).
