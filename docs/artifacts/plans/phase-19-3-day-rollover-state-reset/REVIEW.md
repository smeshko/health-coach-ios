# Review Summary — phase-19-3-day-rollover-state-reset

**Rounds:** 3
**Fix commits:** a41c319..159c2d2

## Rounds

| Round | Findings | Fixed | Deferred | Rejected |
|-------|----------|-------|----------|----------|
| 1     | 1        | 1     | 0        | 0        |
| 2     | 2        | 1     | 0        | 1        |
| 3     | 4        | 2     | 0        | 2        |

Round 3 produced action rows, so per protocol the user was consulted: **fix and ship, no round 4**
(the round-3 stream had degraded — one finding factually wrong, one a re-push of an accepted risk).

## Fixes

### Round 1
- `a41c319` — cancel the check-in child's in-flight load/save effects at rollover; `rolloverReset`
  alone is a pure state mutation, so a pre-midnight effect suspended across midnight delivered into
  the freshly reset state (re-seeding yesterday's answers / stamping `lastSavedAt` from today's
  clock / firing a stale `checkInSaved` delegate). Day-guarded `_currentLoaded` as defense in depth.
  Race tests verified RED without the cancellation. (round-1 #1)

### Round 2
- `776a87a` — day-scope the save success: a save resolving past midnight with the scene continuously
  active (no re-activation → no cancel) stamped `lastSavedAt` with the new day's clock and fired the
  delegate, whose orchestration stamped `contentDay` to today — permanently masking the rollover.
  `saveResponse.success` now carries the persisted day key; a stale-day success clears the spinner
  only. (round-2 #1)

### Round 3
- `159c2d2` — `rolloverGuardOnEntry` at the stamp write point (both orchestration factories): any
  orchestration entered with a stale `contentDay` (post-midnight save/retry on a continuously active
  scene) resets per-day state and cancels the check-in child's effects BEFORE stamping —
  `sceneBecameActive`'s rollover leg now delegates to it (one detector, one reset site). Verified
  RED: without the guard the post-midnight save test hydrates yesterday's pick (selectedIndex 1)
  into today's carousel. Also closes round-3 #1's micro-window (midnight between `saveResponse` and
  the delegate) for free. (round-3 #1, #2)

## Deferred

- (none)

## Rejected

- (round-2 #2, re-pushed as round-3 #4) prior-day `.ready` brief remains renderable while the
  rollover's async gate check runs — explicitly accepted in validation round-1 #8 and recorded in
  PLAN.md Risks: the window is one local GRDB read, and the alternative (moving `briefState` in the
  reset) invents a synthetic loading state outside the orchestration's ownership; the re-orchestration
  lands the full-screen `.checkInRequired` gate immediately after.
- (round-3 #3) `try?` around `sessionSelectionRepository.current` "swallows cancellation → stale
  sends" — demonstrably incorrect: TCA's `Send.callAsFunction` guards `!Task.isCancelled`
  (Effect.swift:192), so a cancelled effect cannot deliver actions regardless of `try?`; the chain
  also does `try Task.checkCancellation()` after the gate read.
