# Validation Summary — phase-19-1-healthkit-ingest-correctness

**Rounds:** 3
**Plan status at validation:** draft
**Run on:** 2026-07-10

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 5        | 5 (one partial) | 1 (split from #1) | 0 |
| 2     | 3        | 2       | 0        | 1 |
| 3     | 1        | 1       | 0        | 0 |

## Applied

### Round 1
- PLAN.md:Risks, DECISIONS.md:D1, TASK-001 — corrected the false "newest-first keeps new
  data" claim; added truncation visibility (per-type count at `limitPerType` → warning on
  the always-on `.http` log category, pure counting seam tested) (round-1 #1, partial —
  prevention deferred, see below)
- TASK-004, PLAN.md:Acceptance — composite child-query registry for dynamically spawned
  effort-relationship queries, registered upfront with `BoundedReadCoordinator`;
  fake-handle timeout/cancellation tests (round-1 #2)
- TASK-003, PLAN.md:Acceptance — pure `distanceMeters(sumForType:)` resolution seam
  tested end-to-end for cycling/swimming/rowing/no-statistics, not just a pinned
  candidate list (round-1 #3)
- TASK-004, DECISIONS.md:D2 — effort preference seam takes timestamped samples;
  newest-by-date within class pinned over unordered inputs (round-1 #4)
- TASK-004 — direct, unconditional membership assert for both effort quantity types in
  `HKTypeCatalog.allReadTypes` (the recordQuerySpecs coverage guard can't catch their
  omission) (round-1 #5)

### Round 2
- TASK-004, PLAN.md:Acceptance — exact stopped-count contract (`stoppedHandleCount`
  summed by the coordinator) so a registry stopping N children isn't Boolean-underreported
  (round-2 #2)
- TASK-004, PLAN.md:Acceptance — one-shot success-path stop for the long-running
  `HKWorkoutEffortRelationshipQuery` (stop exactly once on first delivery, result
  preserved; existing sample queries keep zero-stop success semantics) (round-2 #3)

### Round 3
- TASK-004, PLAN.md:Acceptance — stopped count means failure/cancellation cleanup ONLY;
  normally-completed one-shot children excluded; mixed-outcome test added (round-3 #1 —
  an interaction defect the round-2 fixes introduced)

## Deferred

- (round-1 #1) Truncation-safe delivery (anchored queries / pagination / partitioned
  windows) — out of scope per DECISIONS.md D1; the lookback fully fixes the epic's named
  late-arrival types (sleep/HRV/RHR, orders of magnitude below the 10k/48h cap), and this
  phase ships the truncation warning that serves as the documented trigger to run the
  anchored-query follow-up if the pathological case ever materializes on device.

## Rejected

- (round-2 #1) "Do not defer truncation prevention; design anchored/pagination this
  phase" — rejected, grounded in DECISIONS.md D1 and the epic's acceptance scope; the
  pathological case (>10k samples of one type inside 48h) affects HR load-aggregate
  precision, not the readiness/safety inputs this epic repairs. Round 3's Codex verdict
  explicitly confirmed the rejection is "not factually contradicted by repository
  evidence".
