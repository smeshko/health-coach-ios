# Decisions: HealthKit ingest correctness (Phase 19.1)

## D1 — Lookback watermark, not anchored queries

**Options weighed:**
1. **`HKAnchoredObjectQuery` migration** — the HK-native "insertion order" delta
   mechanism; captures every late arrival exactly once, including arbitrarily backdated
   entries.
2. **Lookback window on the existing startDate watermark** — delta floor becomes
   `max(backfillFloor, anchor − 48h)`; late arrivals inside the window are re-read on the
   next sync.

**Chosen: 2 (lookback).** Rationale:
- Anchored queries require per-sample-type opaque `HKQueryAnchor` blobs → a watermark
  schema migration (24+ anchors), a `HealthKitClient` interface change (anchors in
  `HealthReadBounds`, new anchors out of `HealthSampleSet`), and a rewrite of the
  Phase 18.2 bounded-read/truncation semantics — a large, risky change none of which is
  testable on the sim (anchors are opaque, store-generated).
- The sync is idempotent by design (watermark advances only on success; backend upserts by
  uuid), so re-sending a 48h tail is correctness-neutral and cheap (low thousands of rows,
  `limitPerType` 10000, newest-first truncation).
- The epic text explicitly allows "a watermark that captures late arrivals".
- Residual limitations (documented, accepted — validation round-1 #1):
  1. A manual entry backdated by more than 48h is still missed. Watch transfer latency is
     minutes-to-hours; 48h covers a fully skipped day.
  2. If a single type exceeds `limitPerType` (10000) inside the window, newest-first
     truncation cuts the oldest rows — exactly where a late arrival with an old startDate
     sorts — and later windows won't cover it, so truncation can still permanently drop a
     late sample. Readiness-critical types (sleep/HRV/RHR/dietary) are orders of magnitude
     below the cap; only continuous high-frequency HR approaches it. In-scope mitigation is
     **visibility** (truncation warning on the always-on `.http` log category when a type's
     count reaches the limit), not prevention.
  Trigger to revisit with anchored queries: either limitation observed on device (a
  missing late sample, or the truncation warning firing in practice).

  Validation round-2 #1 pushed back on visibility-only, demanding a truncation-safe
  delivery design (anchored/pagination/partitioned windows) in this phase. **Rejected,
  grounded in scope**: the epic's acceptance criterion names sleep/HRV/RHR late arrivals
  — types that run 2–4 orders of magnitude below the 10k cap — and the lookback fully
  fixes them. The pathological case requires >10k samples of ONE type inside 48h
  (~3.5 samples/min continuously); only continuous HR recording approaches it, and its
  marginal effect is load-aggregate precision, not the readiness/safety inputs this epic
  repairs. Prevention is the anchored-query follow-up, triggered by the warning this
  phase ships — not silent, not unbounded.

## D2 — Effort via `HKWorkoutEffortRelationshipQuery`, not interval matching

**Options weighed:**
1. **Relationship query per workout** (`HKQuery.predicateForObject(with: uuid)`) — the
   canonical iOS 18+ association Apple actually writes.
2. **Query effort samples as a record type and associate to workouts client-side by time
   overlap** — pure-logic association, more testable.
3. **Honest nil only** — delete the bogus metadata read, always send nil.

**Chosen: 1.** Rationale: interval matching re-implements an association HealthKit
already stores and can mis-attribute back-to-back workouts; the relationship query needs
only the workout UUID (no non-Sendable `HKWorkout` crosses a boundary); workout counts per
sync are single-digit so the per-workout query cost is trivial. Option 3 fails the
"populated when the platform provides it" acceptance criterion.

Two implementation constraints (validation round-1 #2/#4):
- **Lifecycle ownership**: the relationship queries are spawned *after* the coordinator's
  fixed lifecycle array is built, so they need an owned registration point — a composite
  child-query registry (itself a `QueryCancelling` registered with the coordinator
  upfront) that forwards `stop()` to every dynamically added child. A fake-handle test
  must prove timeout/cancellation stops all children exactly once and post-cancellation
  deliveries don't contribute.
- **Deterministic selection**: the pure preference seam takes *timestamped* samples
  (date + value per class), because "latest wins" is undecidable from bare values;
  newest-by-date within user-logged, else newest-by-date within estimated, rounded to Int.

## D3 — Workout type on the wire: snake_case name strings

**Options weighed:**
1. **snake_case names** (`"running"`, `"high_intensity_interval_training"`) — exactly the
   backend's canonical form and both repos' fixture form.
2. **Prefixed CamelCase** (`"HKWorkoutActivityTypeRunning"`) — the seeded/offline form the
   backend also canonicalizes.

**Chosen: 1.** The backend's `_canonical_activity_type` lowercases un-prefixed input
without splitting camel boundaries, so bare CamelCase (`"highIntensityIntervalTraining"`)
would corrupt; the prefixed form works but is noise on the wire and diverges from every
fixture. Mapping is an explicit exhaustive `switch` over `HKWorkoutActivityType` (an @objc
enum — no case-name reflection exists); `@unknown default` falls back to
`String(rawValue)` (today's behavior, deterministic, never wrong-name).
