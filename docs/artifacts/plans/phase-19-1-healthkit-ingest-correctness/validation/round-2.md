# Adversarial Validation — Round 2

**Run:** 2026-07-10 (Codex)
**Plan:** phase-19-1-healthkit-ingest-correctness
**Status at start:** draft
**Prior rounds in scope:** validation/round-1.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the deferred replay-loss defect remains a permanent data-loss path, and the new effort-query plan still conflicts with the coordinator’s counting contract and leaves a required long-running-query stop path unverified.

Findings:
- [high] Deferring truncation safety leaves a known permanent-loss path (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/DECISIONS.md:23-34)
  The triage accepts a warning instead of preventing the exact loss scenario round 1 identified. Once a per-type newest-first query exceeds its cap, an old-start-date late arrival can be omitted; after the watermark advances, later 48-hour windows no longer include it. A post-read count warning neither retrieves the omitted sample nor prevents the irreversible watermark advance. This contradicts the plan goal of complete ingest for readiness inputs.
  Recommendation: Do not defer this as visibility-only. Specify a truncation-safe delivery mechanism (anchored reads, pagination, or partitioned windows) and a test proving every late sample inside the supported replay interval is read before the watermark can advance.
- [high] The composite registry does not satisfy the required exact stopped-query instrumentation (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/tasks/TASK-004-workout-effort-score-via-effort-relationship-samples-honest-nil-otherwise.md:22-28)
  The plan says the registry can be inserted as one QueryCancelling entry without changing BoundedReadCoordinator. But the coordinator reports `lifecycles.count { $0.handleWasStopped }`: QueryCancelling exposes only a Boolean, so a registry that stopped N children can contribute only 0 or 1, not N. This silently underreports the very instrumentation that claims to show every in-flight query was stopped; the proposed registry tests do not cover the emitted count.
  Recommendation: Revise the coordinator/registry contract to aggregate an exact stopped-handle count (rather than a Boolean per lifecycle), and add timeout and caller-cancellation tests asserting the reported count includes every dynamic child.
- [high] The long-running effort queries have no specified or tested success-path stop (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/tasks/TASK-004-workout-effort-score-via-effort-relationship-samples-honest-nil-otherwise.md:29-35)
  The plan requires stopping after the first delivery, but its cited QueryLifecycle behavior only drops later callbacks. QueryLifecycle.finish transitions to finished without stopping its registered handle, and existing coordinator success tests explicitly expect zero stops. HealthKit documents this relationship query as long-running and caller-stopped; without an explicit `store.stop(query)`/one-shot lifecycle path, successful effort reads can remain active and continue delivering updates. The planned tests cover cancellation only, not first-delivery cleanup.
  Recommendation: Define a one-shot relationship-query wrapper that stops the concrete query exactly once on its initial callback while preserving the successful result, and add a fake-handle test asserting one stop on normal first delivery as well as timeout/cancellation.

Next steps:
- Replace the visibility-only truncation defer with a loss-prevention design.
- Redesign dynamic-child accounting and add exact-count coverage.
- Add an explicit first-delivery stop path and test for effort relationship queries.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Visibility-only truncation defer leaves a permanent-loss path; demands anchored/pagination design this phase | high | reject | Grounded in D1 + epic scope: the acceptance criterion names sleep/HRV/RHR — 2–4 orders of magnitude below the 10k/48h cap, fully fixed by the lookback. The pathological >10k-of-one-type case affects only HR load-aggregate precision, and the shipped truncation warning is the documented trigger for the anchored-query follow-up. Rejection rationale recorded in DECISIONS.md D1. | |
| 2 | Composite registry underreports the coordinator's stopped-query count (Boolean per lifecycle, N children → ≤1) | high | apply | Real contract conflict with `lifecycles.count { $0.handleWasStopped }` — extend to an exact `stoppedHandleCount` contract summed by the coordinator, tested on timeout + caller-cancellation. | TASK-004, PLAN.md:Acceptance |
| 3 | Long-running relationship queries have no success-path stop (`finish` drops callbacks but never stops the handle) | high | apply | Real leak — one-shot wrapper stopping the concrete query exactly once on first delivery, preserving the result, tested; existing sample queries keep zero-stop success semantics. | TASK-004, PLAN.md:Acceptance |
