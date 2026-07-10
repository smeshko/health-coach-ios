# Adversarial Validation — Round 3

**Run:** 2026-07-10 (Codex)
**Plan:** phase-19-1-healthkit-ingest-correctness
**Status at start:** draft
**Prior rounds in scope:** validation/round-1.md, validation/round-2.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the round-2 exact-count fix conflicts with the newly required success-path stop, so failure telemetry can overcount stopped in-flight queries. D1’s scoped truncation rejection is not factually contradicted by repository evidence.

Findings:
- [medium] Lifetime stop counting will overreport timeout/cancellation cleanup (docs/artifacts/plans/phase-19-1-healthkit-ingest-correctness/tasks/TASK-004-workout-effort-score-via-effort-relationship-samples-honest-nil-otherwise.md:29-43)
  TASK-004 proposes summing a registry's exact `stoppedHandleCount` while also requiring each relationship query to stop normally on first delivery. The actual coordinator’s callback is explicitly the count of in-flight queries stopped during timeout/cancellation. If one relationship query completes and stops normally, then another read later times out or is cancelled, a lifetime count includes the already-completed query and logs it as failure cleanup. The specified tests cover all-child failure and normal success separately, not this mixed outcome.
  Recommendation: Track failure/cancellation stops separately from normal one-shot stops, and have `BoundedReadCoordinator` sum only the former. Add a mixed-outcome test: one child completes and is stopped normally, then a remaining child causes timeout/cancellation; emitted count must include only the still-in-flight child.

Next steps:
- Revise TASK-004 and PLAN acceptance to define the two stop-count meanings and add the mixed-outcome coordinator test.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Lifetime stop count would overreport failure cleanup once success-path stops exist (interaction of round-2 #2 and #3 fixes) | med | apply | Real semantic conflict introduced by the round-2 edits themselves — count failure/cancellation stops only; mixed-outcome test added. Act-and-stop per the round-3 protocol (finding count converged 5→3→1; this refines the prior round's own fix, not plan structure). | TASK-004, PLAN.md:Acceptance |

Note: Codex explicitly confirmed the round-2 #1 rejection ("D1's scoped truncation
rejection is not factually contradicted by repository evidence").
