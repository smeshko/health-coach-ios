# TASK-003: Characterize concurrent sync() watermark behavior

Depends on: None
Suggested commit: `test(sync): characterize concurrent runSync watermark behavior`

## Goal

Pin — with a deterministic test — what two concurrent `runSync()` calls do to the
watermark today, and record (in a code comment + DECISIONS.md D2) that no in-flight guard
ships because the only caller serializes. Test-only — no production change.

## Files

- `Sources/Repositories/SyncRepository/Tests/SyncRepositoryLiveTests/SyncOrchestrationTests.swift`
  — add the concurrent-call characterization test, reusing the existing stub harness
  (`SyncStubs`, the in-memory DB, the Sofia `withDependencies` recipe) the other
  orchestration tests use.
- `Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift` — add ONE comment
  above `runSync()` noting the no-guard decision (the only caller serializes via
  `cancelInFlight`; see DECISIONS.md D2). No logic change.

## Acceptance

- [ ] A deterministic test runs two `sync()` calls whose POSTs are gated so both read the
      same starting watermark, then complete in a controlled order, and asserts the
      resulting watermark state (last writer's `readInstant` wins; the documented
      current behavior). The test name + comment state it pins behavior, not a guard.
- [ ] The `runSync()` comment records the no-guard rationale.
- [ ] No production logic change; existing SyncOrchestration tests green.
- [ ] Host + sim suites green.

## Steps

### RED
- [ ] Write the test: stub `apiClient.sync` to suspend on a per-call gated continuation so
      both invocations are in-flight together (both having read the seed watermark);
      release them in a chosen order; assert the final `SyncWatermarkRecord` matches the
      documented last-writer-wins outcome. Deterministic — no wall-clock sleeps.

### GREEN
- [ ] n/a — characterization; add the explanatory comment.

### REFACTOR
- [ ] Confirm the existing orchestration tests are unaffected; host + sim suites.

## Notes

DECISIONS.md D2 explains why this is characterized, not serialized: the only caller
(TodayFeature orchestration) runs sync under `.cancellable(cancelInFlight: true)`, so the
race is not reachable in-app. If a second caller is ever added, this test is the tripwire
to revisit serialization. Keep the test deterministic via gated continuations on the
stubbed `sync` — do not rely on real concurrency timing.
