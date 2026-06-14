# Plan: Audit residual test hardening — races + entry-point coverage

Status: in-progress
Branch: chore/audit-residual-test-hardening
Risk: medium
Epic: none
Phase: none
Created: 2026-06-13

## Goal

Close the residual findings from the 2026-06-12 unit-test audit
([test-audit-2026-06-12](../../test-audit-2026-06-12.md)) that Epic 11 did not
absorb — the concurrency/race coverage, two untested module entry points, and two
shallow WEAK tests — fixing the one reachable bug (LogViewer out-of-order reload)
and pinning the rest with characterization tests.

## Scope

Eight items, grouped:

- **One real fix** — `LogViewerFeature`'s `onAppear`/`refreshTapped` reload effect has
  no cancellation, so two rapid taps race and a stale `logsLoaded` can win. Add
  `.cancellable(id:, cancelInFlight: true)` + an out-of-order test.
- **Three concurrency characterizations** (no production change — behavior already
  correct or unreachable, pin it):
  - `AppFeature._appWillAppear` single-subscription dedupe (already
    `.cancellable(cancelInFlight: true)`).
  - `SyncRepository.runSync()` concurrent-call watermark behavior (the only caller,
    TodayFeature, serializes via `cancelInFlight` — pin current behavior + record the
    no-guard decision).
  - `LogFileWriter` concurrent-enqueue line integrity (the serial-actor guarantee the
    writer's design hangs on).
- **Two module entry-point coverage tests**:
  - `Database.makeLive(path:)` on-disk open + cross-open migration idempotency (every
    existing test uses `makeInMemory()`).
  - HealthKit `HKSampleMapping.recordQuerySpecs.sampleType ⊆ HKTypeCatalog.allReadTypes`
    (a queried type absent from the authorization read set silently returns nothing on
    device).
- **Two WEAK strengthenings**:
  - `DevMenuFeatureTests.test_viewLogsTapped` — route a child action through the
    presented `LogViewer` state instead of asserting `ifLet` plumbing.
  - `CalendarTests.testUseEuropeSofiaPinsCalendarAndTimeZone` — assert the pin through
    a `\.timeZone` consumer, not by reading back what the setter wrote.

## Out of Scope

- **`test_perTabStacks_startEmpty`** (the third WEAK) — legitimately blocked: the Week/You
  drill-down stacks stay caseless until Epics 9/10 add pushable destinations; the test's
  own comment says strengthening "returns with those cases". Not actionable now.
- **Hardening `runSync()` with serialization** — rejected (DECISIONS.md D2): the only
  caller already serializes; adding an in-flight guard to a stateless repository function
  is blast radius for an unreachable race in a single-user app. This plan characterizes,
  it does not serialize.
- Any behavior change beyond the single LogViewer `cancelInFlight` fix.
- Re-litigating Epic 11's already-merged DELETE/MERGE verdicts.

## Research Summary

See [RESEARCH.md](RESEARCH.md) — every target verified against the post-Epic-11 tree
(staging @ `9e8ec22`) with exact file:line anchors: the LogViewer effect with no
`.cancellable`, the already-correct `_appWillAppear` cancellation, `runSync()`'s
read→write watermark window, `makeLive(path:)` vs the in-memory test path, the two
HealthKit catalogs, the `LogFileWriter` serial actor, and the two WEAK test sites. Note
the topology moved under 11.7: `CheckIn`/`StrengthTest` are now `LocalRepositories`,
`Database`/`TokenClient` are single targets.

## Decisions

See [DECISIONS.md](DECISIONS.md):

- D1 — LogViewer double-refresh is **fixed** (`.cancellable(cancelInFlight: true)`), not
  pinned-as-is — it is a reachable (if minor) out-of-order bug.
- D2 — the concurrent-`sync()` race is **characterized + documented**, not serialized —
  the only caller serializes; a guard is blast radius for an unreachable path.

## Risks

- **Flaky concurrency tests** — the characterizations (sync race, LogFileWriter enqueue,
  double-subscribe) must be deterministic. Mitigation: drive them with TCA's
  `TestClock`/serial executor and gated stubs (continuations), never wall-clock sleeps;
  assert structural invariants (line wholeness, single delivery), not timing.
- **HealthKit test host/sim gate** — HealthKit tests may be sim-only (repo precedent:
  a host-only HK test was deleted in 6.2). Mitigation: the new cross-catalog test
  mirrors `HKReadSetCoverageTests`' placement and run-gate exactly (it already
  references `recordQuerySpecs`); if that suite runs, this assertion runs with it.
- **LogViewer fix changes an effect's identity** — adding `.cancellable` could alter
  TestStore expectations elsewhere. Mitigation: the existing LogViewer tests
  (`onAppear`, `refreshTapped`, `clearTapped`) are re-run; only the new race test
  depends on the cancellation.
- **`makeLive` test leaves temp files** — an on-disk test writes a real SQLite file.
  Mitigation: use a unique temp path under `NSTemporaryDirectory()` and delete it in the
  test teardown.

## Acceptance Criteria

- [ ] LogViewer reload is cancellable: a second `refreshTapped`/`onAppear` while one is
      in flight cancels the first; only the latest `logsLoaded` lands (new test green;
      existing LogViewer tests still green).
- [ ] `_appWillAppear` delivers a session event exactly once after a double-subscribe
      (characterization test green).
- [ ] Concurrent `runSync()` behavior is pinned by a deterministic test and the no-guard
      rationale is recorded in DECISIONS.md.
- [ ] `Database.makeLive(path:)` is covered: open-on-disk + a second open over the same
      file (migration idempotency) with row persistence; temp file cleaned up.
- [ ] A test asserts every `HKSampleMapping.recordQuerySpecs.sampleType` is contained in
      `HKTypeCatalog.allReadTypes`.
- [ ] `LogFileWriter` concurrent enqueue yields whole, non-interleaved lines under N
      parallel writers.
- [ ] The two WEAK tests assert real behavior (a routed child action; a `\.timeZone`
      consumer) rather than plumbing/setter readback.
- [ ] Full host suite + sim unit tests green; `make lint` clean.

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: Guard LogViewer reload against out-of-order double-refresh
- [ ] TASK-002: Pin _appWillAppear single-subscription dedupe
- [ ] TASK-003: Characterize concurrent sync() watermark behavior
- [ ] TASK-004: Cover Database.makeLive on-disk open and migration path
- [ ] TASK-005: Assert HealthKit recordQuerySpecs are a subset of allReadTypes
- [ ] TASK-006: Pin LogFileWriter concurrent-enqueue line integrity
- [ ] TASK-007: Strengthen the two shallow WEAK tests (DevMenu viewLogs, Calendar timeZone)
- [ ] TASK-008: Final Validation
