# Adversarial Validation — Round 1

**Run:** 2026-07-10
**Plan:** phase-18-2-bounded-hk-reads
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan does not preserve caller-driven cancellation, its required log dependency is absent, and its validation can pass without compiling or exercising the iOS HealthKit path.

Findings:
- [high] Keeping the current outer timeout wrapper defeats immediate caller cancellation (docs/artifacts/plans/phase-18-2-bounded-hk-reads/tasks/TASK-003-syncrepository-bounds-wiring-timedout-transient-outer-backstop-kept-tests.md:13-19)
  Verdict: apply — `withSyncTimeout` launches the HealthKit operation in an unstructured `Task` and never observes cancellation of its awaiting caller (current `SyncRepository+Live.swift:158-179`). Today’s Cancel cancels the orchestration effect, but that does not cancel this child task; the query can therefore survive until the 15s client timeout or complete normally. This contradicts the plan’s “not survive its caller” goal and makes the proposed Cancel-mid-sync evidence non-probative.
  Recommendation: Change PLAN.md, TASK-003, and TASK-004: make the 20s backstop structured or explicitly forward parent cancellation to the operation task, and add an executable test proving Today-style cancellation causes the client cancellation path before the timeout.
- [high] The specified `.app` instrumentation will not compile under the current target graph (docs/artifacts/plans/phase-18-2-bounded-hk-reads/tasks/TASK-002-live-reads-per-type-limit-desc-sort-stop-query-on-cancel-in-client-timeout.md:24-32)
  Verdict: apply — TASK-002 requires `@Dependency(\.log)` and `.app` logging, but `HealthKitClientLive` currently depends only on `HealthKitClient`, `WireModels`, and `Dependencies` (`Package.swift:354-360`). The `DependencyValues.log` member is declared in the separate `LogClient` module (`LogClient.swift:63-67`), so it is neither imported nor linked by this target. The planned implementation has a compile-time dependency missing from its Files list.
  Recommendation: Change TASK-002 and RESEARCH.md to include `Package.swift` (add the `LogClient` target dependency) and `import LogClient` in the live reader, plus a build/compile acceptance check for that target.
- [medium] Final validation can green-light code the host test suite never compiles (docs/artifacts/plans/phase-18-2-bounded-hk-reads/tasks/TASK-004-final-validation.md:12-22)
  Verdict: apply — TASK-004 calls for a full suite and a manual simulator smoke test, but does not require an iOS build/test command. `make test` is explicitly macOS-host-only (`Makefile:20-22`), while the HealthKit implementation is behind `#if canImport(HealthKit)` and the package documents that the iOS path is exercised only on simulator/device (`Package.swift:351-353`). Thus the changed cancellation handlers, timeout race, and HealthKit query constructors can fail to compile or behave incorrectly while the stated automated gate passes; a manual log check is not an equivalent compile/test gate.
  Recommendation: Change PLAN.md, RESEARCH.md, and TASK-004 to require and record a pinned simulator `xcodebuild test` or at minimum an iOS build that compiles `HealthKitClientLive`; make it explicit which non-snapshot tests run there and retain the cancellation-log evidence separately.

Next steps:
- Resolve the two high-severity plan gaps before implementation; then make the simulator build/test gate explicit in final validation.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | `withSyncTimeout`'s unstructured Task never forwards caller cancellation — stop-on-cancel unreachable from Today's Cancel | high | apply | Correct and load-bearing for the phase goal; wrapper must cancel its children on caller cancel + executable propagation test | TASK-003:Files/Tests, PLAN.md:Scope/Acceptance, RESEARCH.md |
| 2 | `.app` logging can't compile: LogClient not a dependency of HealthKitClientLive | high | apply | Verified against Package.swift; add target dependency + import | TASK-002:Files, RESEARCH.md |
| 3 | Host-only `make test` never compiles the `canImport(HealthKit)` arm | med | apply | Pinned-simulator package test run added as a mandatory recorded gate | TASK-002:Acceptance, TASK-004:Steps, PLAN.md:Acceptance, RESEARCH.md |
