# Plan: HealthKit ingest correctness

Status: in-progress
Branch: fix/phase-19-1-healthkit-ingest-correctness
Risk: medium
Epic: 19 — Make the numbers trustworthy (audit wave 2) ([epic](../../epics/19-trustworthy-numbers.md))
Phase: 19.1 — HealthKit ingest correctness
Linear: none
Created: 2026-07-10

## Goal

Ingested HealthKit samples are complete and correctly typed on the wire: late-arriving
Watch samples are no longer permanently dropped by the watermark, workouts carry distance
for every endurance modality, effort comes from where Apple actually stores it, and
`Workout.type` is the name string the backend contract expects — so readiness, load and
targets are computed from the athlete's real inputs.

## Scope

- `Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift` — lookback window
  on the delta-read floor so samples written after the last sync but started before it are
  re-read (backend upserts by uuid, so re-sends are safe).
- `Sources/Clients/HealthKitClient/Live/HKSampleMapping.swift` — workout `type` name
  string, multi-modality distance, effort-score extraction.
- `Sources/Clients/HealthKitClient/Live/HKDeltaReads.swift` — effort-relationship read
  wired into the bounded workouts read.
- `Sources/Clients/HealthKitClient/Live/HKTypeCatalog.swift` — read authorization for the
  effort-score quantity types.
- Tests at the existing pure-logic seams (SyncRepository bounds capture; new pure mapping
  functions in HKSampleMapping).

## Out of Scope

- Anchored-query (`HKAnchoredObjectQuery`) migration — see DECISIONS D1; the lookback
  watermark satisfies the acceptance criteria without an interface/schema migration.
- `zoneMinutes`/`workout_statistics` upload (iOS omits them today; separate contract gap,
  not named by Phase 19.1).
- Backend changes of any kind (backend already canonicalizes name strings).
- Cache invalidation, day rollover, backend invariants — Phases 19.2–19.5.

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing findings:

- The sync watermark stores the wall-clock `readInstant` (captured before the HK read) and
  the delta query filters `startDate >= since` with `.strictStartDate` — so any sample
  whose `startDate` precedes the last sync but which lands on the phone after it (overnight
  Watch sleep/HRV/RHR transfers, backdated dietary entries) is excluded by every future
  query. `SyncRepository+Live.swift` builds the bounds via `anchorDate(anchor)`.
- The backend `/sync` ingest upserts workouts/records by `uuid`, and
  `_canonical_activity_type` expects name strings (fixtures: `"running"`, `"boxing"`,
  `"high_intensity_interval_training"`); the live client sends
  `String(workout.workoutActivityType.rawValue)` — a numeric code like `"37"` that
  canonicalizes to itself and never matches `HARD_ACTIVITY_TYPES` or any classification.
- Distance is read only via `HKQuantityType(.distanceWalkingRunning)` statistics, so
  cycling/swimming/rowing workouts upload `distanceM = nil`.
- `metadata["HKWorkoutEffortScore"]` is not a HealthKit metadata key; Apple stores effort
  as `HKQuantityType(.workoutEffortScore)` / `.estimatedWorkoutEffortScore` samples related
  to the workout via `HKWorkoutEffortRelationshipQuery` (iOS 18+; package floor is iOS 26).
  Reading them needs those types in the read-authorization set (`HKTypeCatalog`).
- Test seams: SyncRepository tests capture `HealthReadBounds` via a stubbed
  `healthKitClient` (`SyncBoundedReadTests`); HK mapping logic must be extracted into pure
  functions to be testable on the sim (the live query path has zero tests — audit).

## Decisions

See [DECISIONS.md](./DECISIONS.md) — D1 lookback-vs-anchored watermark, D2 effort via
relationship query vs interval matching, D3 type-name mapping format.

## Risks

- Lookback re-sends up to 48h of already-synced samples every sync — mitigated: backend
  upsert by uuid dedups; typical volume (~1–3k HR samples per 48h) is far under
  `limitPerType` 10000.
- **Truncation can still defeat the lookback** (validation round-1 #1): if a type exceeds
  `limitPerType` within the window, newest-first truncation cuts the *oldest* rows — which
  is exactly where a late-arriving old-startDate sample sorts — and later windows no longer
  cover it. Mitigated in-scope by visibility: when any type's returned count equals
  `limitPerType`, log a truncation warning on the always-on `.http` category so the
  condition is diagnosable on device. The truncation-*safe* fix (anchored queries) is the
  documented D1 follow-up trigger, not this phase.
- Effort-relationship read adds per-workout queries to the bounded read — mitigated:
  workouts per sync window are few (single-digit), each query is wrapped in the same
  `QueryLifecycle` stop/cancel machinery, and a failing/denied query degrades to `nil`
  effort (empty-slice-not-error philosophy).
- `HKWorkoutActivityType` mapping table can drift from future SDK cases — mitigated:
  `@unknown default` falls back to the numeric string (today's behavior), and the mapped
  set is pinned by tests for every modality the product classifies.
- Changing `test_sync_requestsBoundedRead_sinceAnchor_defaultLimitAndTimeout` semantics —
  the expected `since` becomes `anchor − lookback` (clamped at `backfillFloor`); update the
  assert with the rationale in the test name, don't weaken it.

## Acceptance Criteria

- [ ] A sleep/HRV/RHR sample written after the watermark advanced (startDate before it) is
  still ingested on the next sync: the delta-read floor is `max(backfillFloor,
  anchor − 48h)`, pinned by a SyncRepository bounds-capture test.
- [ ] A cycling/swimming/rowing workout maps a non-nil `distanceM`: the distance
  resolution is a pure per-type-sums → first-non-nil seam, tested end-to-end through the
  mapping result for cycling, swimming, rowing, and a no-statistics (strength/rest)
  workout — not merely a pinned candidate list.
- [ ] `Workout.type` on the wire is the snake_case name string the backend canonicalizes
  (e.g. `"running"`, `"high_intensity_interval_training"`), pinned by tests over every
  product-relevant `HKWorkoutActivityType` case.
- [ ] `effortScore` is populated from related `workoutEffortScore` (preferring user-logged
  over estimated, newest-by-date within a class) when present, and is honestly `nil`
  otherwise — the bogus metadata read is gone; both effort quantity types are asserted
  members of `HKTypeCatalog.allReadTypes` by a direct, unconditional test.
- [ ] Dynamically spawned effort-relationship queries are owned by the bounded read:
  fake-handle tests prove timeout/cancellation stops every child query exactly once (the
  coordinator's stopped count includes each child — exact-count contract, no Boolean
  underreporting), a post-cancellation delivery cannot contribute, and the long-running
  relationship query is stopped exactly once on normal first delivery too (one-shot
  success path). The stopped count means failure/cancellation cleanup only — a
  mixed-outcome test pins that a normally-completed child is not counted.
- [ ] Delta-read truncation is visible: a per-type count hitting `limitPerType` logs a
  warning on the always-on `.http` category (pure counting seam tested).
- [ ] All package tests green on the canonical sim (`make test-sim`); no snapshot changes
  expected.

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: Watermark lookback window so late-arriving samples are re-read
- [ ] TASK-002: Workout type name-string mapping (replace numeric rawValue on the wire)
- [ ] TASK-003: Multi-modality workout distance extraction
- [ ] TASK-004: Workout effort score via effort-relationship samples (honest nil otherwise)
- [ ] TASK-005: Final Validation
