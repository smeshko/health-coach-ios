# Adversarial Validation — Round 2

**Run:** 2026-07-10
**Plan:** phase-18-4-db-token-discrimination
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)
**Prior rounds in scope:** validation/round-1.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

(First invocation returned a no-diff false-approve — "the supplied target has no working-tree
diff" — because the plan dir is untracked/gitignored; re-run with explicit review-the-FILES
framing. Output below is the re-run.)

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the revised plan can fail to compile, and it still does not prove its audit-critical logs are emitted by the new failure paths.

Findings:
- [high] Proposed public action exposes an internal associated type (docs/artifacts/plans/phase-18-4-db-token-discrimination/tasks/TASK-002-appfeature-three-state-token-restore-present-absent-read-failed.md:13-18)
  `AppFeature.Action` is public (`AppFeature.swift:72`), so its `_tokenChecked` case cannot use a default-internal nested `TokenRestore`. TASK-002 specifies `enum TokenRestore` without `public`; implementing that literally produces an access-control compile error before tests run.
  Recommendation: Specify `public enum TokenRestore: Equatable, Sendable` (or an equivalent public associated-value type), then compile the AppFeature target as part of the task validation.
- [medium] The always-on logging fix remains unverified at the new call sites (docs/artifacts/plans/phase-18-4-db-token-discrimination/tasks/TASK-001-databaselive-corruption-vs-transient-discrimination-journal-sidecar-logged-recovery.md:69-73)
  I agree that moving the records to `.http` fixes the release gate: existing LogClientLive tests prove arbitrary `.http` records bypass disabled settings. But TASK-001 explicitly says its tests must assert behavior rather than capture logs, so neither its preserve nor quarantine test proves that the newly required decision record exists or uses `.http`. A regression to `.app` or removal of the record would still pass the proposed tests and recreate the audit's no-trace failure mode. TASK-003 adds no targeted logging check.
  Recommendation: Add log assertions for both database recovery decisions and AppFeature `.readFailed`: capture the call-site record, assert `.http`, the classification/result code, and absence of raw error payloads. Add the needed direct LogClient test dependency in Package.swift; retain the existing LogClientLive all-settings-off test as the release-gate proof.

Next steps:
- Make TokenRestore public and add call-site logging tests before implementation.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | `TokenRestore` needs `public` (Action is public) — compile error as specced | high | apply | Correct; access level specced explicitly | TASK-002:Files |
| 2 | `.http` decision records unverified at call sites — silent regression possible | med | apply | Correct; log-capture assertions added for both DB decisions + AppFeature readFailed, with the LogClient test dep noted | TASK-001:Files/Notes, TASK-002:Tests |
