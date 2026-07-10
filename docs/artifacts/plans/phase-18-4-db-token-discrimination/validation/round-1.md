# Adversarial Validation — Round 1

**Run:** 2026-07-10
**Plan:** phase-18-4-db-token-discrimination
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan leaves release diagnostics unverifiable and declares the epic done while required device validation remains open.

Findings:
- [high] Required failure diagnostics are gated off in release (docs/artifacts/plans/phase-18-4-db-token-discrimination/tasks/TASK-001-databaselive-corruption-vs-transient-discrimination-journal-sidecar-logged-recovery.md:20-26)
  TASK-001 mandates `.app` logs for the preserve/quarantine decisions, and TASK-002 uses the same category. Current LogClientLive drops every non-`.http` category unless a DevSettings toggle is enabled; release resolves those toggles off. The plan therefore preserves data but recreates the audit's “no trace” failure mode, while TASK-001 explicitly avoids log capture. Verdict: apply — the stated logging acceptance criterion cannot be met in a release build as written.
  Recommendation: Apply: update PLAN.md, TASK-001, TASK-002, and TASK-003 to require an always-on, safely redacted classification signal (or an equivalent durable diagnostic) and test that it is emitted with release-equivalent settings.
- [medium] Final validation would falsely mark Epic 18 Done (docs/artifacts/plans/phase-18-4-db-token-discrimination/tasks/TASK-003-final-validation.md:19-26)
  The task says to leave the physical-device criterion open, yet also set EPICS.md to Done. That contradicts the repository’s Done definition (“all phases complete and validated”) and current Epic 18 still has pending owner device criteria in phases 18.1 and 18.2. This can unblock dependent work on an unverified device-first remediation. Verdict: apply — completion state must not claim the open acceptance criteria are complete.
  Recommendation: Apply: update PLAN.md and TASK-003 to retain Epic 18 as In progress (or introduce an explicit owner-validation status) until all device criteria are evidenced; do not set EPICS.md to Done beforehand.
- [medium] The token-failure fallback relies on a 401 path that may never run (docs/artifacts/plans/phase-18-4-db-token-discrimination/tasks/TASK-002-appfeature-three-state-token-restore-present-absent-read-failed.md:21-25)
  The task claims that an actually-gone token will be routed by the first API-call 401, but the live transport calls tokenClient.read() before it creates or sends a request. If the Keychain read continues throwing—the exact readFailed condition—there is no HTTP request and no session event. The proposed TestStore stops after dispatching onAppOpen, so it does not establish a recovery path for persistent read failure. Verdict: apply — the plan’s fallback rationale is not true for the current transport order.
  Recommendation: Apply: update PLAN.md, TASK-002, and TASK-003 to define and test the persistent-Keychain-error outcome (for example, a deliberate foreground/manual re-read recovery path and observable error state) instead of asserting that 401 will route it.

Next steps:
- Revise the three cited plan tasks before implementation, then re-run plan validation against release-equivalent logging and the unresolved Epic 18 device gate.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | `.app` diagnostics are toggle-gated/off in release — "no trace" failure mode recreated | high | apply | Correct; decision lines moved to the always-on `.http` category (18.1 precedent eec3e20), redacted to path + result code | TASK-001:Files, TASK-002:Files, PLAN.md:Scope/Decisions |
| 2 | TASK-003 would set EPICS.md Done with owner device criteria open | med | apply | Correct; row becomes `Implemented — owner device validation pending`; open criteria listed in the PR body | TASK-003:Steps, PLAN.md:Decisions |
| 3 | 401-routes-it rationale false under persistent keychain failure (no request is ever built) | med | apply | Correct; outcome spectrum documented honestly (transient → next per-call read succeeds; persistent → Today's sync-error surface + `.http` log, relaunch recovers); comments must not claim 401 coverage | TASK-002:Files, PLAN.md:Decisions |
