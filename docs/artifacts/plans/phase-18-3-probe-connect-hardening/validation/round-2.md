# Adversarial Validation — Round 2

**Run:** 2026-07-10
**Plan:** phase-18-3-probe-connect-hardening
**Status at start:** draft
**Reviewer:** subagent (general-purpose; Codex usage-limited)
**Prior rounds in scope:** validation/round-1.md

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

Verdict: needs-attention

Findings:

1. [med] The round-1 clear-on-edit effect is unordered w.r.t. the next `connectTapped` write — a pending clear can strip the bearer after the re-tap re-writes it. TASK-001 (tasks/TASK-001:17–23) shapes the edit arm as a merged `.cancel(id: CancelID.probe)` + a detached fire-and-forget `.run { tokenClient.clear() }`, while `connectTapped` writes the candidate then probes with the bearer read from TokenClient per request (ConnectComponent.swift:78–88, DECISIONS 1). Effects are concurrent tasks, so edit→quick-re-tap can interleave as write → clear → probe: the probe goes out unauthenticated, the server 401s, and the reducer renders `.invalid` ("token doesn't look right") for a token that is actually valid — the exact "probe lies about the token" class this phase exists to kill, now reachable via the round-1 edit itself. The fix is also a cleaner shape than the merge: make the edit arm a single `.run { try? await tokenClient.clear() }.cancellable(id: CancelID.probe, cancelInFlight: true)` — `cancelInFlight` kills the in-flight probe (replacing the explicit `.cancel`, and avoiding the merge's undefined cancel-vs-register ordering under one ID), and registering the clear under `CancelID.probe` means the next `connectTapped`'s own `cancelInFlight: true` cancels any still-pending clear before writing. Recommendation: Verdict: apply — respecify the edit-arm effect as one cancellable clear under `CancelID.probe` instead of merged `.cancel` + detached `.run` — TASK-001 (Files, Notes), PLAN.md (Decisions bullet 2).

2. [low] TASK-001 omits the ripple into the existing binding test its own edit creates. `test_editingToken_afterError_resetsValidationToIdle` (ConnectComponentTests.swift:69–78) sends `.binding(.set(\.token, …))` against today's `.none`-returning arm, with no dependency overrides and no `await store.finish()`; once `.binding` returns the clear effect, the TestStore will report an in-flight effect at deinit (the `tokenClient.clear` actor hop won't reliably complete before the test ends — the testValue box at TokenClient+TestValue.swift:7–14 is functional, so no unimplemented-dependency failure, just the in-flight one). TASK-001's test bullets (tasks/TASK-001:31–41) enumerate the failure-test split and the new cancel test precisely but not this file's third affected test, so a literal implementer hits an unexplained RED outside the listed scope. Recommendation: Verdict: apply — add one bullet: "existing `test_editingToken_afterError_resetsValidationToIdle` gains `await store.finish()` (and should assert the clear via the recorder)" — TASK-001 (Files/tests).

Grounding notes (checked, no defect): the prompt's flagged interactions are otherwise clean — `BindingReducer()` runs before the `Reduce` (ConnectComponent.swift:60–61), so the `.binding` arm sees post-write state and per-keystroke cancel+clear is semantically what PLAN Risks accepts (no valid token is ever stored while Connect is frontmost: the 401-bounce token is invalid by definition and success navigates away). The epic-AC amendment (TASK-004:27–34) does not conflict with `link_plan.py` — the script rewrites only the `**Plan**:` line of the phase block, never the AC text, and the epic's current AC-2/Validation wording (18-run-on-device.md:139–147) does need the rewrite round-1 #5 ordered. `ErrorDisplay.serverUnreachable` has no hidden ripple: `LabelsGalleryPage` renders only `.upstreamTimeout` (line 34), `DisplayLabelTests` never iterates `ErrorDisplay.allCases` (only the named `tokenRejected` test at 59–66), and the three feature presenters map `BriefError`→`ErrorDisplay` non-exhaustively over the new case. ConnectView's `.invalid` checks are all equality (lines 104/108/111/133), so TASK-001 stays compile-safe, and no test outside ConnectComponentTests sends `binding`/`tokenPasted`. Round-1 triage stands as applied — #2's untestability reframe is correct (`canSubmit` at ConnectComponent.swift:34–36 plus the now-cancelling edit arms leave no reachable concurrent second probe), and cancelled effects can't deliver `probeResponse` (TCA's `Send` drops sends from cancelled tasks, so the `catch`-arm `send(.probeResponse(.failure(CancellationError)))` at line 86–87 is inert).

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Detached clear can interleave write → clear → probe → false `.invalid` on a valid token | med | apply | Correct — edit arm respecified as ONE `.run { clear }.cancellable(id: .probe, cancelInFlight: true)`; next connectTapped cancels a pending clear before writing; ordering test added | TASK-001:Files/Tests, PLAN.md:Decisions |
| 2 | Existing binding test hits an unexplained in-flight-effect RED | low | apply | Bullet added: `await store.finish()` + assert the clear via recorder | TASK-001:Tests |
