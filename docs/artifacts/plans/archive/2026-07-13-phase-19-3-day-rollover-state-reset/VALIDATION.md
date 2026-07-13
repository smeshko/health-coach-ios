# Validation Summary — phase-19-3-day-rollover-state-reset

**Rounds:** 3 (reviewer: general-purpose subagent, adversarial framing — Codex usage-capped)
**Plan status at validation:** draft
**Run on:** 2026-07-10

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 10       | 9       | 1        | 0        |
| 2     | 3        | 3       | 0        | 0        |
| 3     | 3        | 2       | 0        | 1 (note) |

## Applied

### Round 1
- TASK-001, PLAN.md:Acceptance, RESEARCH.md — `isBackgroundRefreshing = false` joined
  the reset contract (a rollover-cancelled background pass can never clear the flag →
  stuck "Updating…" pill) (round-1 #1)
- TASK-001, PLAN.md:Acceptance — the existing rollover test needs a `contentDay` seed
  under the nil-must-not-trigger rule (round-1 #2)
- TASK-001 — stamp mechanism specified: `inout State` factory signatures; four reducer
  trigger sites inherit the stamp (effects cannot mutate state) (round-1 #3)
- TASK-001, DECISIONS.md:D2, PLAN.md:Risks — background-pass-straddling-midnight
  semantics + the deliberate brief.date→stamp change documented (round-1 #4; REVERSED
  in round 2 — see below)
- TASK-001 — explicit guard shape: rollover leg covers all stamped states incl.
  in-flight `.syncing`/`.generating`; the same-day staleness leg stays `.ready`-gated
  (`isStale(nil, nil) == true` would otherwise fire over `.checkInRequired`) (round-1 #5)
- TASK-003 — pure `overrideZoneRange` helper (view-body derivation is untestable) +
  hand-rolled fixture note (no existing fixture has triggered+activeRecovery+zoneTarget)
  (round-1 #6)
- TASK-001, PLAN.md:Acceptance — `.syncFailed` added to the rollover terminal matrix
  (round-1 #7)
- PLAN.md:Risks — the ≥1-frame gutted-`.ready` window accepted explicitly (round-1 #8)
- TASK-001, TASK-002 — `.onAppOpen` (not `.task`) and the corrected snapshot-safety
  reason (round-1 #10)

### Round 2
- TASK-001, DECISIONS.md:D2, PLAN.md:Risks — **reversal of round-1 #4's mitigation**:
  background trigger sites must NOT stamp (`pullToRefresh` is `.ready`-gated, not
  same-day-gated — stamping at 00:01 would mask the rollover permanently); the stale
  stamp after a cross-midnight pass is the correct recovery (round-2 #1)
- TASK-001, PLAN.md:Acceptance — the ~29-send mechanical `$0.contentDay` test sweep
  named so RED noise isn't misread (round-2 #2)
- TASK-001 — the two stale lifecycle doc comments to update (round-2 #3)

### Round 3
- TASK-001 — staleness-leg clause fixed to "`== today` or `nil`" with a
  do-not-literalize note (round-3 #1); doc-comment bullet refiled to TodayFeature.swift
  (round-3 #3)

## Deferred

- (round-1 #9) Post-reset late child-save race (check-in save effect has no cancel ID;
  a cross-midnight save restamps `lastSavedAt` briefly) — sub-second, self-healing
  (the save delegate re-runs the gate for the new day); round 2 re-verified the
  self-heal path in code.

## Rejected

- (round-3 #2, note) The existing rollover test's exhaustive send will also need a
  `$0.contentDay = today` trailing-closure assert — self-announcing via TestStore
  exhaustivity; the named sweep primes the pattern.

Round 3's verdict: "The plan is ready for implementation as written," with the rollover
recovery path (stale stamp → reset → re-gate, no loop) confirmed against the code.
