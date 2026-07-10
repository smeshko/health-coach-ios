# TASK-001: Watermark lookback window so late-arriving samples are re-read

Depends on: None
Suggested commit: `fix(sync): apply 48h lookback to the delta-read floor so late-arriving samples are re-read`

## Goal

The delta-read floor becomes `max(backfillFloor, anchor − 48h)` so a sample whose
startDate precedes the last sync but which landed on the phone after it (overnight Watch
sleep/HRV/RHR, backdated dietary entries) is ingested by the next sync instead of being
permanently dropped.

## Files

- `Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift` — introduce a
  `deltaLookback: Duration/TimeInterval = 48h` constant next to `backfillFloor`; the
  bounds construction uses `max(backfillFloor, anchorDate(anchor) − lookback)` (only when
  an anchor exists — a nil anchor already reads from `backfillFloor`). Document WHY in a
  short comment (late-arriving Watch transfers; backend upserts by uuid so re-sends are
  safe).
- `Sources/Repositories/SyncRepository/Tests/SyncRepositoryLiveTests/SyncBoundedReadTests.swift`
  — update `test_sync_requestsBoundedRead_sinceAnchor_defaultLimitAndTimeout` (since ==
  anchor − 48h) and add: (a) a lookback test proving a sample-window floor 48h before the
  anchor, (b) a clamp test proving an anchor within 48h of `backfillFloor` floors at
  `backfillFloor`, not before it.
- Truncation visibility (validation round-1 #1): in
  `Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift`, after the delta
  read, compute per-type counts over the returned `HealthSampleSet` (records grouped by
  `RecordType`, workouts, activity) via a pure helper; if any count `>= limitPerType`,
  log a truncation warning on the **always-on `.http` category** (the Epic-18 convention
  for audit-critical records — `.app` is toggle-gated). Test the counting helper pure
  (a set with a type at the limit → flagged; below → not).

## Acceptance

- [ ] Captured `HealthReadBounds.since == anchor − 48h` for a normal anchor.
- [ ] Captured `since == backfillFloor` when `anchor − 48h` would precede the floor, and
  for the nil-anchor first sync (unchanged behavior).
- [ ] Watermark advance is untouched — it still stores the pre-read `readInstant`
  (existing tests keep passing).
- [ ] A `HealthSampleSet` with any per-type count at `limitPerType` produces a truncation
  warning on the `.http` log category; below the limit produces none (pure counting seam
  pinned by test).

Evidence: test output of the SyncRepositoryLiveTests suite showing the new/updated
bounds-capture asserts green.

## Steps

### RED
- [ ] Update/add the bounds-capture tests above; run — the since asserts fail against the
  current `anchorDate(anchor)` floor.

### GREEN
- [ ] Add the lookback constant and apply it in `runSync`'s bounds construction with the
  clamp.

### REFACTOR
- [ ] Keep `anchorDate`/`anchorString` round-trip untouched (the persisted anchor format
  does not change); confirm `SyncOrchestrationTests`/`SyncTimeoutTests` still pass.

## Notes

- Do NOT change what is persisted — the anchor stays the raw `readInstant`; the lookback
  is applied at read time so tuning it later needs no migration.
- `HealthReadBounds.presenceProbe` and `runLastSync` are unaffected.
