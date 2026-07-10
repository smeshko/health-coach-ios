# Plan: Bounded, cancellable HealthKit reads

Status: done
Branch: fix/phase-18-2-bounded-hk-reads
Risk: medium
Epic: 18 — Make it run on device (audit wave 1) ([epic](../../epics/18-run-on-device.md))
Phase: 18.2 — Bounded, cancellable HealthKit reads
Linear: none
Created: 2026-07-10

## Goal

No HealthKit read can run unbounded or survive its caller: the read interface expresses a row
limit + since-floor + timeout, and the live implementation actually stops the underlying
`HKQuery` on cancellation/timeout instead of abandoning it.

## Scope

- `HealthReadBounds` (since + per-type row limit + timeout) and `HealthKitReadError.timedOut`
  in the `HealthKitClient` interface; `deltaSamples` takes the bounds struct (single argument,
  so `{ _ in }` stubs across feature tests keep compiling).
- Live `HKDeltaReads`: per-type `limit` with **descending** startDate sort (replaces
  `HKObjectQueryNoLimit`), `withTaskCancellationHandler` + `HKHealthStore.stop(query)` on
  cancel, and an in-client timeout race that cancels the query group (so timeout ⇒ stop) and
  throws `.timedOut`. One `.app`-category log line when queries are stopped (epic validation
  instrumentation).
- `SyncRepository`: pass bounds (since = anchor, default limit, 15s in-client timeout), map
  `HealthKitReadError.timedOut` → `SyncError.transient`, keep the 20s abandoning
  `withSyncTimeout` as outer backstop — AND make it forward caller cancellation to the
  operation task (today the unstructured child `Task` outlives a cancelled caller, so
  Today's Cancel never reaches the read; validation round-1 #1).
- Mechanical call-site adaptation in `HealthKitPriming` (same `.distantPast` probe semantics,
  now bounded as a side effect) — the probe/CTA rework itself is Phase 18.3.

## Out of Scope

- Watermark/ingest correctness (startDate-vs-readInstant, distance/effort/type mapping) —
  Epic 19 Phase 19.1.
- Onboarding probe UX, CancelID, token handling — Phase 18.3 (only the compile-level call-site
  adaptation happens here).
- True chunked/paging first sync — the bounded partial read (newest-N per type) is the chosen
  degradation (see Decisions).
- Live-`HKHealthStore` unit tests — host-only HK tests were deleted by prior decision
  (memory: sim-unit-tests-must-pass); live behaviour is covered by instrumentation + the
  owner's device validation.

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing: the 2026-06-18 CR-3 fix (`withSyncTimeout`)
only *abandons* a wedged read — `runRecordQuery`/`readWorkouts`/`readActivity` still use
`HKObjectQueryNoLimit`, never observe cancellation, and their queries are never `stop()`ed, so
an orphaned first-sync read keeps accumulating millions of rows (heart rate, active energy,
steps are in `recordQuerySpecs`). `deltaSamples` is single-argument, so switching `Date` →
`HealthReadBounds` leaves every `{ _ in ... }` feature-test stub compiling; only
`SyncRepository+Live.swift:66` and `HealthKitPriming.swift:106` name the parameter.

## Decisions

- **DESC sort + per-type row limit (default 10 000), not chunked paging** — with a limit,
  truncation must drop something; sorting descending by `startDate` drops the *oldest*
  samples, which matches the existing `backfillFloor` philosophy (old history deliberately
  skipped) and can never lose *new* data going forward — after the first sync, delta windows
  are day-scale and never hit the limit. Ascending sort + naive watermark advance would
  silently skip the newest samples forever (a new Epic-19-class bug). Paging is real
  complexity for a first-sync-only problem.
- **Timeout enforced inside the live client (15s), outer 20s backstop kept** — the in-client
  race cancels the task group → cancellation handlers `stop()` every in-flight query → no
  orphan; it must fire *before* the repo's abandoning `withSyncTimeout` (20s), which stays as
  the belt-and-suspenders for a `stop()` that itself wedges.
- **`HealthKitReadError.timedOut` in the interface; repo maps it to `SyncError.transient`** —
  callers keep one retryable-failure vocabulary; the per-category empty-slice-never-error
  contract (PRD §7.1) is unchanged (a *failing* category still yields `[]`; only the
  whole-read timeout throws).
- **Once-guarded continuation resume on cancel** — `stop(query)` does not guarantee the
  result handler fires; the cancellation handler must resume the continuation itself
  (`CancellationError`), guarded against double-resume with the result callback (same
  `ResumeOnceFlag` pattern as `withSyncTimeout`).
- **One `.app` log line when queries are stopped** — the epic's validation asks for the
  cancelled read to be "shown stopping via log/instrumentation"; `.app` is the right category
  for non-HTTP app diagnostics (owner enables the toggle in the dev menu).

## Risks

- `stop(query)` semantics on one-shot `HKSampleQuery` are under-documented — mitigated by the
  once-guarded resume (never rely on the callback firing after stop) and the outer backstop.
- Signature change ripples wider than grep found — mitigated: single-argument struct keeps
  positional stubs compiling; `make test` + sim suite are the gate.
- Default limit too tight for a heavy first sync (watch-wearer heart rate) — deliberate:
  bounded partial read is the accepted degradation; the constant is named, documented, and
  trivially adjustable.

## Acceptance Criteria

- [x] A read that times out or is cancelled stops the underlying `HKQuery` — code path
  verified by review + the `.app` "stopped N queries" log line demonstrated in a simulator
  run (cancel mid-sync via the Today screen's Cancel, or the timeout branch under a TestClock
  in repo tests). *(Sim run 2026-07-10: healthd suspended → sync hung on the HK read →
  Today's Cancel → `NOTICE [app] HK read cancelled/timed out — stopped 25 in-flight
  queries`; no orphan POST followed.)*
- [x] Caller cancellation propagates end-to-end: cancelling the task awaiting `sync()`
  cancels the in-flight `deltaSamples` before any timeout (unit-tested with a
  cancellation-observing stub client; validation round-1 #1).
  *(`test_sync_callerCancelled_cancelsDeltaRead_noPost_watermarkUntouched` passed.)*
- [x] The iOS (`canImport(HealthKit)`) arm is compiled by the pinned-simulator CoachApp
  build (transcript shows `HKDeltaReads.swift`) — `make test` is host-only and the package
  scheme omits `HealthKitClientTests` (validation round-1 #3 + round-2 #2). *(BUILD
  SUCCEEDED; transcript: `SwiftCompile … HKDeltaReads.swift (in target 'HealthKitClientLive')`.)*
- [x] A cancelled read can neither complete as success nor leak a running query:
  `QueryLifecycle` (linearizable register/execute/cancel protocol — cancel-before-
  registration never executes; late callbacks dropped) and `BoundedReadCoordinator`
  (TestClock-driven timeout → `.timedOut` + every registered handle stopped exactly once)
  pinned by deterministic host tests with fake query handles (validation round-2 #1,
  round-3 #1, round-3 #2). *(QueryLifecycleTests + BoundedReadCoordinatorTests suites green.)*
- [x] The delta read enforces a per-type row bound and the since-date floor (interface tests
  + repo test asserting the bounds passed to the client carry since = anchor and the default
  limit). *(`test_sync_requestsBoundedRead_sinceAnchor_defaultLimitAndTimeout` +
  HealthReadBoundsTests green.)*
- [x] `HealthKitReadError.timedOut` surfaces as `SyncError.transient` before any watermark
  write (unit-tested with a TestClock); existing `SyncTimeoutTests` backstop behaviour
  unchanged. *(`test_sync_clientTimedOut_throwsTransient_watermarkUntouched` +
  SyncTimeoutTests green.)*
- [x] Full suite + lint green on the sim (`make test`, snapshot targets untouched).
  *(467 tests / 95 suites passed; `swiftlint --strict` 0 violations in 379 files.)*
- [ ] CI-pending (owner): first-ever sync on a physical device with a large HealthKit history
  completes within its timeout or degrades to the bounded partial read (epic Validation).

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: HealthReadBounds + HealthKitReadError interface; signature + call-site adaptation
- [x] TASK-002: Live reads: per-type limit + DESC sort, stop(query) on cancel, in-client timeout (depends on TASK-001)
- [x] TASK-003: SyncRepository bounds wiring: timedOut→transient, outer backstop kept, tests (depends on TASK-002)
- [x] TASK-004: Final Validation
