# Validation Summary — phase-18-3-probe-connect-hardening

**Rounds:** 3
**Plan status at validation:** draft
**Run on:** 2026-07-10
**Reviewer:** general-purpose subagent all rounds (Codex usage-limited; established fallback)

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 5        | 5       | 0        | 0        |
| 2     | 2        | 2       | 0        | 0        |
| 3     | 4        | 4       | 0        | 0        |

## Applied

### Round 1
- TASK-001, PLAN.md — cancel-on-edit must also clear the just-written candidate
  (cancel suppresses the failure arm holding the only `clear()`; an unvalidated stored
  token flips next launch to `.main`) (round-1 #1)
- TASK-001, PLAN.md — `cancelInFlight` reframed (concurrent second probe unreachable via
  `canSubmit`) (round-1 #2)
- TASK-002, PLAN.md — snapshots are light+dark PNG pairs, wording fixed (round-1 #3)
- TASK-002 — copy lives at the D19 boundary: `ErrorDisplay.serverUnreachable` in
  DesignSystem + DisplayLabelTests (round-1 #4)
- TASK-004 — epic AC wording amended to cancellation+presentation semantics BEFORE
  ticking (round-1 #5)

### Round 2
- TASK-001, PLAN.md — edit arm respecified as ONE `.run { clear }.cancellable(id: .probe,
  cancelInFlight: true)`; a detached clear could interleave write → clear → probe and 401
  a valid token; ordering test added (round-2 #1)
- TASK-001 — existing binding test gains `await store.finish()` + clear assertion
  (round-2 #2)

### Round 3 (cooperative-cancellation refinements; TCA mechanics verified against vendored source)
- TASK-001, PLAN.md — `Task.checkCancellation()` leads the clear body; cancellation-aware
  parked stubs required in tests; Decisions wording softened to best-effort +
  one-actor-hop residual (round-3 #1)
- TASK-001 — `checkCancellation` before the probe effect's token write (round-3 #2)
- TASK-001 — failure-arm clears registered under `CancelID.probe` (round-3 #3)
- TASK-001 — NOTE qualified: pending-clear cancellation is the testable half (round-3 #4)

## Deferred

- none

## Rejected

- none

**Note:** rounds ran to the 3-round cap with applies each round under the user-ordered
autonomous mode. Rounds 2–3 converged on one mechanism (correctly-ordered, cooperative
cancellation of the write/clear/probe bodies under a single CancelID) now fully specced in
TASK-001; concluded without a fourth round.
