# Review Summary — phase-18-2-bounded-hk-reads

**Rounds:** 3
**Fix commits:** 3ff5d5d..5d387c2 + the escalation resolution (round-3 #1 fix, committed
after the owner decision)
**Status:** ✅ RESOLVED — round 3 produced one [low] fix row and the review escalated per
protocol; the owner chose **act-and-stop** (apply the one-line fix + regression test, no
fourth round — the finding series converged high → med → low). The fix is committed below.

## Rounds

| Round | Findings | Fixed | Deferred | Rejected |
|-------|----------|-------|----------|----------|
| 1     | 1        | 1     | 0        | 0        |
| 2     | 3        | 2     | 0        | 1        |
| 3     | 3        | 0 (1 open) | 1   | 1        |

## Fixes

### Round 1
- `3ff5d5d` — cooperative `Task.checkCancellation()` after the bounded read, before the
  `/sync` POST, and before the watermark write, so cancellation racing a successfully
  completing delta read can no longer carry a cancelled sync into side effects; deterministic
  regression tests for the pre-POST and during-POST boundaries (round-1 #1)

### Round 2
- `b7a07db` — `HealthReadBounds` fields are `let` and the init clamps `limitPerType` to
  `>= 1`, making HealthKit's no-limit sentinel (`HKObjectQueryNoLimit` == 0) and negative
  values unrepresentable (round-2 #3)
- `5d387c2` — the activity-summary window is floored at `limitPerType` days before now via
  `HealthReadBounds.activitySince` (`HKActivitySummaryQuery` has no `limit` parameter; one
  summary per day makes the window the cardinality bound), so the `.distantPast` onboarding
  probe can no longer request an unbounded activity range (round-2 #2)

### Round 3 (escalation resolution — owner chose act-and-stop)

- (round-3 #1) The inclusive day-bucket predicate spans `limitPerType + 1` days, so the
  activity window could return one row more than the claimed cap — fixed:
  `activitySince` floors at `-(limitPerType - 1)` days, existing floor test corrected,
  `test_activitySince_limitOne_spansExactlyToday` regression pin added
  (25 HealthKitClientTests green).

## Deferred

*(Linear not wired in this session — recorded here only.)*

- (round-3 #2) `limitPerType` has no upper clamp: `Int.max` is operationally unbounded and
  can push `activitySince`'s calendar math into its `since` fallback — reachable only by a
  caller deliberately passing an absurd explicit limit (every app call site uses the
  `.since(_:)` defaults; unlike the 0 sentinel, `Int.max` is not an innocent idiom).
  Follow-up: pick a documented finite ceiling and make the `activitySince` fallback
  conservative (`now`, not `since`).

## Rejected

- (round-2 #1 / round-3 #3) Cancellation arriving between the pre-POST
  `Task.checkCancellation()` and `apiClient.sync(request)` can still dispatch the POST —
  the window is inherent to cooperative cancellation: the proposed dispatch gate has the
  identical race one instruction after its linearization point, and a request already on
  the wire can never be recalled. The residual is harmless by design: `/sync` is idempotent
  with last-writer-wins characterized by `test_concurrentSync_lastWriterWins_noGuard` (the
  documented no-guard decision in `runSync`), the pre-write check still blocks the watermark
  advance, and the live URLSession transport throws promptly on task cancellation.
