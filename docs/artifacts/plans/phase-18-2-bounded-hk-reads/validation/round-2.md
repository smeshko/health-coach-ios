# Adversarial Validation — Round 2

**Run:** 2026-07-10
**Plan:** phase-18-2-bounded-hk-reads
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)
**Prior rounds in scope:** validation/round-1.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the round-1 cancellation fix still admits a cancellation-to-success race, and its new iOS validation gate targets the wrong scheme and may not build the live reader.

Findings:
- [high] Cancellation can race into a successful empty read (docs/artifacts/plans/phase-18-2-bounded-hk-reads/tasks/TASK-002-live-reads-per-type-limit-desc-sort-stop-query-on-cancel-in-client-timeout.md:18-23)
  TASK-002 requires `onCancel` to call `stop(query)` and share a once-guard with the callback, but does not require cancellation to atomically win that race. A callback triggered while/after `stop` can claim the guard first and complete normally (often with an empty result), allowing the cancelled operation to continue. TASK-003 then returns cancellation to the caller while its unstructured operation can still proceed toward POST/watermark work. The proposed stub test only observes cancellation; it does not exercise callback-vs-cancel ordering.
  Recommendation: Specify a synchronized completion state where cancellation marks/claims `CancellationError` before calling `stop`, and callbacks cannot return success once cancellation is recorded. Add a deterministic helper test for a callback that fires during `stop`, plus a sync-level assertion that cancellation causes no POST or watermark write.
- [high] The required simulator gate is not a runnable proof that HealthKitClientLive compiled (docs/artifacts/plans/phase-18-2-bounded-hk-reads/tasks/TASK-002-live-reads-per-type-limit-desc-sort-stop-query-on-cancel-in-client-timeout.md:50-54)
  The command names `CoachKit-Package` while passing `CoachApp.xcodeproj`, but that project exposes the `CoachApp` scheme; the package scheme exists under `.swiftpm/xcode/package.xcworkspace`. Further, the current package scheme lists its selected test targets and does not include `HealthKitClientTests`, the target that directly depends on `HealthKitClientLive`. Thus the round-1 fix for the uncompiled `canImport(HealthKit)` arm can still be marked complete without compiling the changed implementation.
  Recommendation: Replace this with a verified invocation using the package workspace, or mandate an iOS `CoachApp` build. Ensure the chosen scheme explicitly builds/tests `HealthKitClientLive` (for example by adding its test target to the package scheme), and require the transcript to show that target/source compiled; do not leave a bare `-skip-testing:` placeholder.

Next steps:
- Repair the cancellation state machine and its race coverage before implementation.
- Make the iOS build/test command target the actual scheme and explicitly cover HealthKitClientLive.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Cancel-vs-callback race: late callback can claim success after cancellation | high | apply | Correct — `QueryCompletion` records cancellation BEFORE `stop()`, callbacks can't claim success once cancelled; helper lives in the Interface target for deterministic host tests; sync-level no-POST assertion added | TASK-002:Files/Acceptance, TASK-003:Tests, PLAN.md:Acceptance |
| 2 | Sim gate names the wrong project/scheme; package scheme omits HealthKitClientTests | high | apply | Verified — scheme lists only CoachCore/AppFeature/snapshot targets, workspace is `.swiftpm/xcode/package.xcworkspace`; gate replaced with the 18.1-proven CoachApp sim build requiring `HKDeltaReads.swift` in the transcript | TASK-002:Acceptance, TASK-004:Steps, PLAN.md:Acceptance |
