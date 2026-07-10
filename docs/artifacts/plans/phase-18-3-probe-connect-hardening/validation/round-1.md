# Adversarial Validation — Round 1

**Run:** 2026-07-10
**Plan:** phase-18-3-probe-connect-hardening
**Status at start:** draft
**Reviewer:** subagent (general-purpose; Codex usage-limited)

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

Verdict: needs-attention

Findings:

1. [high] Cancel-on-edit leaves an unvalidated candidate stored in the Keychain — violating the plan's own invariant. The connect effect writes the candidate *before* probing (ConnectComponent.swift:80–83, DECISIONS 1), and the only `clear()` lives in the `probeResponse(.failure)` arm (line 101). TASK-001 makes `binding`/`tokenPasted` return `.cancel(id: CancelID.probe)`, which suppresses the effect's `send` — so after an edit-mid-probe the failure arm never runs, and if the user abandons/kills the app there, the unvalidated candidate persists and the next launch restores to `.main` — exactly the scenario PLAN.md's Out-of-Scope and Decision 2 declare must not happen ("an unverified candidate must not persist"). The plan closes the *stale-clears-newer* race but opens a *cancel-skips-clear* persistence hole it never mentions. Recommendation: Verdict: apply — the cancel arms must also fire-and-forget `tokenClient.clear()` (safe: any later tap re-writes), or the Decisions section must explicitly accept the window — PLAN.md (Decisions/Risks), TASK-001.

2. [med] The "second `connectTapped` cancels the first probe" acceptance criterion is untestable as specified — `cancelInFlight` is unreachable code. `canSubmit` blocks a re-tap while `.validating` (ConnectComponent.swift:34–36), and per TASK-001 the only actions that exit `.validating` mid-flight (`binding`/`tokenPasted`) themselves cancel the probe. So by the time a second `connectTapped` can fire, the first probe is already cancelled by the edit — the proposed test (TASK-001's own Note admits routing through an edit/`tokenPasted`) proves edit-cancel again, not `cancelInFlight`. PLAN.md AC-1's second clause can't produce distinct Evidence. Recommendation: Verdict: apply — drop the "second submit cancels" clause or reframe `cancelInFlight: true` as untestable defense-in-depth — PLAN.md (AC-1), TASK-001.

3. [med] "Exactly ONE new PNG" is factually wrong — the harness records light+dark pairs. Every existing case has two references (e.g. `__Snapshots__/ConnectViewSnapshotTests/test_connect_errorState.dark.png` + `.light.png`); `assertCoachSnapshot` emits both. The new `.unreachable` case will produce TWO PNGs, so TASK-002's Evidence gate ("`git status` showing exactly one new PNG") and PLAN.md AC-4 / Risks ("the one new unreachable PNG") would either fail or mislead the implementer into discarding a needed reference per TASK-002's "discard the others" instruction. Recommendation: Verdict: apply — say "one new snapshot case (a light+dark PNG pair)" — PLAN.md (AC-4, Risks), TASK-002 (Acceptance, Notes).

4. [med] TASK-002 omits the file where the fixed copy must live — the DesignSystem `ErrorDisplay` boundary. ConnectView's documented rule (ConnectView.swift:12–15) is that the feature authors no raw error string; the `.invalid` row renders `ErrorDisplay.tokenRejected.label` from `Sources/DesignSystem/Sources/Labels/DisplayLabel.swift` (the D19 single presentation boundary). TASK-002 tells the implementer to render "its own fixed copy (implementer picks…)" but lists only ConnectView + the snapshot target — following it literally means an inline string that breaks the very boundary the plan cites; doing it right means a new `ErrorDisplay` case (a cross-target DesignSystem change, plus the `DisplayLabelTests` distinctness convention at DisplayLabelTests.swift:61–65). No gallery ripple: `LabelsGalleryPage` renders only `.upstreamTimeout`, not `allCases`. Recommendation: Verdict: apply — add DisplayLabel.swift (+ its test) to TASK-002's Files and name the new case (e.g. `.serverUnreachable`) — TASK-002, RESEARCH.md (Uncertainty).

5. [med] The epic's acceptance-criterion text contradicts the plan's clearing decision, and TASK-004 will tick it as-is. Epic 18 Phase 18.3 AC-2 reads "a transient probe failure does not clear an otherwise-valid token" (and Validation: "a valid token survives a transient probe failure"), while the plan deliberately clears the candidate on *every* failure (Decision 2) and satisfies the epic only under a reinterpretation ("the token that matters"). TASK-004's epic step ("Tick this phase's Acceptance criteria") would check a box the implementation intentionally does not meet as written. The reinterpretation is defensible (the token stays in `state.token`, re-tap re-writes; a validated token is never re-probed on Connect) but must land in the epic doc, not silently in a tick. Recommendation: Verdict: apply — TASK-004 (or PLAN Decisions) should instruct amending the epic AC/Validation wording to the cancellation+presentation semantics before ticking — TASK-004, docs/artifacts/epics/18-run-on-device.md.

Grounding notes (checked, no defect): ConnectView really uses only equality checks on `Validation` (lines 104/108/111/133), so TASK-001's compile-safety claim holds; `HealthReadBoundsTests.swift` exists at the exact TASK-003 path; the `.unconfigured` client does throw `APIError.transport(...)` (APIClient+Live.swift:36–48), so the discrimination axis is real; the `limitPerType: 365` / activity-window interplay is correctly reasoned (activity folds into the Active & basal row whose record categories keep presence true, `activitySince` floors at `limitPerType − 1` per HealthKitClient.swift:44–49); `OnboardingFeatureSnapshotTests` is in Makefile SNAPSHOT_TARGETS as the plan assumes.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Cancel-on-edit skips the failure-arm clear() → unvalidated candidate persists | high | apply | Correct and violates the plan's own invariant; cancel arms now also fire-and-forget clear | TASK-001:Files/Tests/Acceptance, PLAN.md:Decisions/Acceptance |
| 2 | cancelInFlight acceptance clause untestable (unreachable via canSubmit) | med | apply | Reframed as untestable defense-in-depth; AC clause replaced | TASK-001:Files/Acceptance, PLAN.md:Acceptance |
| 3 | Snapshots record light+dark pairs, not one PNG | med | apply | Wording corrected everywhere | TASK-002:Files/Acceptance/Notes, PLAN.md:Acceptance |
| 4 | Copy must live at the DesignSystem ErrorDisplay boundary (D19), not inline | med | apply | `ErrorDisplay.serverUnreachable` + DisplayLabelTests added to TASK-002 Files | TASK-002:Files/Acceptance, PLAN.md:Acceptance |
| 5 | Epic AC text contradicts the clearing decision; ticking as-is would misreport | med | apply | TASK-004 now instructs amending the epic AC/Validation wording before ticking | TASK-004:Steps, PLAN.md:Decisions |
