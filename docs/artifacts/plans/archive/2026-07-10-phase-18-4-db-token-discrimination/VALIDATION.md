# Validation Summary — phase-18-4-db-token-discrimination

**Rounds:** 3
**Plan status at validation:** draft
**Run on:** 2026-07-10
**Reviewer:** Codex all rounds (round-2 first invocation returned a no-diff false-approve on
the gitignored plan dir; re-run with review-the-FILES framing)

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 3        | 3       | 0        | 0        |
| 2     | 2        | 2       | 0        | 0        |
| 3     | 3        | 3 (two slim) | 2 (machinery arms) | 0 |

## Applied

### Round 1
- TASK-001/TASK-002/PLAN.md — decision/diagnostic records moved to the always-on `.http`
  category (`.app` is toggle-gated, off in release — 18.1 precedent eec3e20) (round-1 #1)
- TASK-003/PLAN.md — EPICS.md row set to `Implemented — owner device validation pending`,
  never `Done`, while owner device criteria remain open (round-1 #2)
- TASK-002/PLAN.md — honest persistent-keychain outcome (Transport reads the token before
  sending → no 401 fires; no false "401 routes it" claim) (round-1 #3)

### Round 2
- TASK-002 — `TokenRestore` specced `public` (Action is public; internal nested payload =
  compile error) (round-2 #1)
- TASK-001/TASK-002 — log-capture assertions at the call sites: category `.http`,
  classification/result codes, no raw payloads; LogClient test dep noted (round-2 #2)

### Round 3
- TASK-001/PLAN.md — preserve-mode write-loss made explicit: Decision bullet + the log
  record says "NEW WRITES WILL NOT PERSIST" (slim arm of round-3 #1)
- TASK-001 — three distinct recovery outcomes logged (preserve / recreate success /
  recreate FAILURE) + stateful CORRUPT-then-BUSY injected-open test — no false
  "recreated" (round-3 #2)
- TASK-002/PLAN.md — degraded-route wording made honest (check-in gate / quiet cache-hit /
  cache-miss error vary; the `.http` log is the reliable trace) (slim arm of round-3 #3)

## Deferred

- (round-3 #1, machinery arm) Read-only persistence state or durable replay queue for
  preserve-mode sessions — real UI+persistence machinery for a rare transient failure on a
  single-owner app; the write-loss trade is now explicit and logged, and the on-disk data
  survives (strictly better than the pre-existing wipe). Follow-up if transient DB
  failures ever occur in practice.
- (round-3 #3, machinery arm) Dedicated recoverable auth/persistence error state with
  foreground token re-read — rare device-level keychain failure; relaunch recovers
  transients; the `.http` log carries the cause. Follow-up with the same trigger.

## Rejected

- none

**Note:** rounds ran to the 3-round cap with applies each round under the user-ordered
autonomous mode; round-3's two [med/high] machinery recommendations were split
apply-the-honesty / defer-the-machinery with rationale recorded in the round file.
