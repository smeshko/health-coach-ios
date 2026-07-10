# TASK-003: SyncRepository bounds wiring: timedOut→transient, outer backstop kept, tests

Depends on: TASK-002
Suggested commit: `fix(sync): wire bounded HK read; map client timeout to transient`

## Goal

`runSync()` requests a bounded read and treats a client-side timeout exactly like the
existing backstop timeout: `SyncError.transient` thrown before any watermark write.

## Files

- `Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift` —
  - step 3 becomes `healthKit.deltaSamples(.since(anchorDate(anchor)))` inside the kept
    `withSyncTimeout(healthReadTimeout /* 20s */)` backstop; map
    `HealthKitReadError.timedOut` → `SyncError.transient` (catch-and-rethrow around the
    read).
  - **Forward caller cancellation through `withSyncTimeout`** (validation round-1 #1): the
    operation currently runs in an unstructured `Task` that never observes the awaiting
    caller being cancelled — so Today's Cancel would never reach the client's
    stop-on-cancel handlers. Wrap the continuation in `withTaskCancellationHandler` whose
    `onCancel` cancels BOTH child tasks (keep handles), letting the operation task's
    cancellation propagate into `deltaSamples` (→ `stop(query)`), and resume via the
    existing once-guard with `CancellationError`.
  - Update the step-3 comment block: caller cancel → structured cancellation → queries
    stopped; in-client 15s timeout STOPS queries (18.2); the 20s abandoning backstop remains
    only for a `stop()` that itself wedges.
- `Sources/Repositories/SyncRepository/Tests/SyncRepositoryLiveTests/` —
  - new test: stub client whose `deltaSamples` records the received `HealthReadBounds` →
    assert `since == anchorDate(anchor)` and the `.since(_:)` defaults (limit 10 000 /
    timeout 15s) — the repo can't silently request unbounded reads again.
  - new test: stub client throws `HealthKitReadError.timedOut` → `sync()` throws
    `SyncError.transient` and the watermark row is untouched.
  - existing `SyncTimeoutTests` (TestClock outer-timeout path) updated only for the
    signature; behaviour identical.
  - new test (round-1 #1): cancelling the task awaiting `sync()` cancels the in-flight
    `deltaSamples` — stub client parks on a never-ending `withTaskCancellationHandler` and
    records `onCancel`; assert the cancellation arrives (before any timeout) and `sync()`
    rethrows `CancellationError`, watermark untouched.
  - same test also asserts NO `apiClient.sync` POST happens after cancellation (recording
    stub apiClient) — a cancelled read must not proceed toward POST/watermark work
    (round-2 #1 sync-level arm).

## Acceptance

- [ ] Bounds-capture test pins since/limit/timeout as requested by `runSync()`.
- [ ] `.timedOut` → `SyncError.transient`, watermark untouched (test).
- [ ] Existing outer-backstop timeout test still passes unchanged in behaviour.
- [ ] `make test` + `make lint` green.

Evidence: `swift test --filter SyncRepositoryLiveTests` output green.

## Steps

### RED
- [ ] Write the bounds-capture and timedOut-mapping tests (fail against TASK-002 state).

### GREEN
- [ ] Wire the bounds + error mapping; update comments.

### REFACTOR
- [ ] Keep `healthReadTimeout` doc comment accurate (backstop, not primary).

## Notes

Do NOT change watermark semantics (anchor still advances to `readInstant` on success —
Epic 19.1 owns watermark correctness). The in-client timeout (15s, from
`HealthReadBounds.since` defaults) must stay strictly below `healthReadTimeout` (20s) — if
either constant changes, assert the ordering in a test or comment prominently.
