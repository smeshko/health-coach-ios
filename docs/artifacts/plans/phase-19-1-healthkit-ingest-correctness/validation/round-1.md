# Adversarial Validation — Round 1

**Run:** 2026-07-10 (Codex)
**Plan:** phase-19-1-healthkit-ingest-correctness
**Status at start:** draft

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the 48-hour replay can still permanently drop late arrivals under the plan’s own documented rate/limit, and the effort-query design lacks a verifiable bounded-lifecycle implementation.

Findings:
- [high] The lookback window loses late samples when the replay is truncated (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/PLAN.md:72-74)
  Verdict: reject — the plan’s own worst-case rate (720 HR samples/hour) exceeds the 10,000-per-type cap within 48 hours. Live reads sort by start date newest-first, so a newly arrived sample with an older start date can fall below the cap behind already-synced newer samples; on the next sync it is outside the window and permanently omitted. “Newest-first keeps new data” is false for this arrival pattern.
  Recommendation: Replace D1 with an ingest-order/anchored strategy, or specify and test pagination/window partitioning that guarantees every late sample inside the replay interval is read before the watermark advances.
- [high] Effort relationship queries are not actually integrated into the current bounded-read coordinator (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/tasks/TASK-004-workout-effort-score-via-effort-relationship-samples-honest-nil-otherwise.md:19-24)
  Verdict: apply — the current coordinator receives a fixed lifecycle array built before the workout callback runs, and only cancels that array. TASK-004 says each per-workout query uses QueryLifecycle but does not define a structured child-query scope/coordinator change, nor a timeout/cancellation test proving every dynamically created relationship query is stopped. A naive implementation can leave HealthKit queries running after the 15-second read fails and silently return incomplete effort data.
  Recommendation: Update TASK-004 and TASK-005 to define lifecycle ownership for dynamically spawned relationship queries and add a fake-handle timeout/cancellation test that proves all child queries stop exactly once and cannot contribute after cancellation.
- [medium] The distance task cannot prove its stated outcome (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/tasks/TASK-003-multi-modality-workout-distance-extraction.md:20-32)
  Verdict: apply — PLAN.md requires a pure mapping test that cycling, swimming, and rowing produce non-nil distanceM, but TASK-003 only pins a static candidate list. That test passes if the helper is never called, uses the wrong quantity/unit, or still returns nil; the current live mapping is exactly an untested statistics shell.
  Recommendation: Update TASK-003 and TASK-005 to extract a pure identifier/value selection seam and test the full mapping result for cycling, swimming, rowing, and no-statistics workouts.
- [medium] “Latest effort wins” is unimplementable from the proposed helper inputs (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/tasks/TASK-004-workout-effort-score-via-effort-relationship-samples-honest-nil-otherwise.md:16-18)
  Verdict: apply — the proposed preference helper accepts only [Double], while the decision requires the latest user-logged or estimated sample to win. Values alone contain no timestamp, and the task neither requires sorting relationship samples nor tests unordered samples with distinct dates. This can select a stale effort score nondeterministically.
  Recommendation: Update TASK-004, DECISIONS.md, and TASK-005 so the pure seam receives timestamped samples (or an explicitly sorted representation) and tests that newest-by-date wins within each source class.
- [medium] The authorization acceptance criterion has no effective planned test (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/tasks/TASK-004-workout-effort-score-via-effort-relationship-samples-honest-nil-otherwise.md:25-31)
  Verdict: apply — TASK-004 says to adjust HKReadSetCoverageTests only if it enumerates workout-category types, but the current guard checks recordQuerySpecs only; effort relationship types are not record query specs. Consequently the existing test remains green even if both effort types are omitted from allReadTypes, yielding silent nil effort on device.
  Recommendation: Update TASK-004 and TASK-005 to require a direct assertion that both effort HKQuantityTypes are members of HKTypeCatalog.allReadTypes; do not condition the test on the existing record-query coverage guard.

Next steps:
- Reject the fixed-window strategy unless truncation-safe delivery is designed and tested.
- Revise TASK-004 before implementation; its current lifecycle, ordering, and authorization evidence cannot demonstrate the plan’s acceptance criteria.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Lookback replay can truncate late arrivals (newest-first + limitPerType) → permanent drop | high | apply (partial) + defer | The false "newest-first keeps new data" claim is corrected and truncation is made visible (per-type count == limit → always-on log + risk documented); the full truncation-safe fix is the anchored-query migration D1 explicitly rejected for this phase — deferred as the trigger-condition follow-up. Readiness-critical types (sleep/HRV/RHR/dietary) are orders of magnitude below the cap; only continuous-HR pathologies approach it. | PLAN.md:Risks, DECISIONS.md:D1, TASK-001 |
| 2 | Per-workout effort relationship queries aren't covered by the fixed lifecycle array the coordinator stops | high | apply | Real integration gap — dynamically spawned child queries need owned lifecycle registration + a fake-handle timeout/cancellation test. | TASK-004, TASK-005 (via PLAN.md acceptance) |
| 3 | Distance test (static candidate list) can't prove non-nil distanceM per modality | med | apply | Extract a pure per-type-sum → first-non-nil seam and test the full mapping result for cycling/swimming/rowing/no-statistics. | TASK-003, PLAN.md:Acceptance |
| 4 | "Latest effort wins" unimplementable from bare [Double] inputs | med | apply | Preference seam must take timestamped samples; pin newest-by-date within class. | TASK-004, DECISIONS.md:D2 |
| 5 | Effort-types-in-read-set criterion has no effective test (coverage guard checks recordQuerySpecs only) | med | apply | Require a direct membership assert on HKTypeCatalog.allReadTypes, unconditional. | TASK-004 |
