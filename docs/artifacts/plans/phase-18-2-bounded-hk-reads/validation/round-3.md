# Adversarial Validation — Round 3

**Run:** 2026-07-10
**Plan:** phase-18-2-bounded-hk-reads
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)
**Prior rounds in scope:** validation/round-1.md, validation/round-2.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: round-2 fixes the callback-after-cancel race, but the plan still permits cancellation before query registration to leak a live HKQuery, and its timeout-stop path has no executable coverage.

Findings:
- [high] Cancellation before query registration can still launch an orphaned query (docs/artifacts/plans/phase-18-2-bounded-hk-reads/tasks/TASK-002-live-reads-per-type-limit-desc-sort-stop-query-on-cancel-in-client-timeout.md:18-26)
  The required state machine orders cancellation before `stop(query)`, but it never specifies an atomic protocol for registering and executing the query. Cancellation can arrive before the continuation has created/stored the query: `onCancel` records the error and has nothing to stop, then the cancelled operation can still execute the newly created query. Dropping its later callback only hides the result; it does not stop the underlying HealthKit work, violating the phase goal.
  Recommendation: Require a linearizable query lifecycle: atomically register the query and its execution state with cancellation, do not execute a query registered after cancellation, and ensure a query registered before cancellation is stopped exactly once. Add deterministic tests for cancellation before registration and between registration and execution.
- [high] The in-client timeout path can pass validation without ever being exercised (docs/artifacts/plans/phase-18-2-bounded-hk-reads/tasks/TASK-002-live-reads-per-type-limit-desc-sort-stop-query-on-cancel-in-client-timeout.md:30-35)
  A TestClock installed in a SyncRepository stub cannot exercise `liveDeltaSamples`; the stub replaces the live client. The task simultaneously says the live race is only structural and excludes live-HK tests, while final validation manually cancels a sync rather than inducing the client timeout. The iOS build proves compilation only, so a broken timeout race that fails to stop queries or reports cancellation instead of `.timedOut` can ship undetected.
  Recommendation: Add an executable seam around the timeout/query coordinator with fake query handles, or an iOS simulator integration test, that advances a TestClock and asserts `.timedOut`, cancellation of every in-flight read, and exactly one stop per handle. Make that test mandatory final-validation evidence.

Next steps:
- Specify and test cancellation-before-registration behavior.
- Add a real timeout-path test before implementing the plan.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Cancel before query registration leaks an executing query | high | apply | Correct — spec upgraded to a linearizable `QueryLifecycle` (register-after-cancel never executes; registered handle stopped exactly once) with deterministic ordering tests | TASK-002:Files/Acceptance, PLAN.md:Acceptance |
| 2 | Timeout race had no executable coverage (stub client bypasses liveDeltaSamples) | high | apply | Correct — timeout moved into a host-testable `BoundedReadCoordinator` (fake `StoppableQuery` handles + TestClock → `.timedOut` + one stop per handle); liveDeltaSamples becomes thin assembly | TASK-002:Files/Acceptance, PLAN.md:Acceptance |

**Round-3 note (protocol):** round-3 applies would normally stop for the user; this run is
user-ordered autonomous. Both findings refine TASK-002's concurrency spec toward the same
testable-coordinator structure — applied and concluded, no fourth round. The structure now
has deterministic host coverage for every cancel/timeout ordering Codex raised across
rounds 2–3.
