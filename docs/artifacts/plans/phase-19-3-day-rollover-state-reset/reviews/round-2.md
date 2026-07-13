# Adversarial Review — Round 2

**Run:** 2026-07-13 11:40 UTC
**Branch:** fix/phase-19-3-day-rollover-state-reset
**Base:** staging
**Commits reviewed:** 0dbd551..a41c319
**Prior rounds in scope:** reviews/round-1.md
**Reviewer:** Codex

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

Do not ship: a41c319 only fixes cancellation-first ordering. A stale save can still win the rollover race and suppress the reset; rollover also leaves prior-day brief content visible for unbounded async latency.

Findings:
- [high] Save completion can beat cancellation and mask rollover permanently (Sources/Features/TodayFeature/Sources/CheckInComponent.swift:153-166)
  The save captures yesterday's day, but `saveResponse` carries no day or generation and success mutates state unconditionally. If that response is processed after midnight but before `sceneBecameActive`—including while the scene remains continuously active—it stamps `lastSavedAt` with today's time and emits the delegate. The delegate starts orchestration, which stamps `contentDay` as today; a later activation therefore sees no mismatch and never resets yesterday's answers. The user can see a false saved footer and resubmit yesterday's answers as today's. The new race test proves only the opposite ordering, where cancellation happens before completion.
  Recommendation: Include the captured day or generation in `saveResponse` and reject stale successes before changing state or emitting the delegate. Normalize/reset stale-day state before any orchestration entry overwrites `contentDay`. Test completion-before-activation, an already-queued response, and continuously active midnight rollover.
- [medium] Prior-day brief remains renderable for unbounded repository latency (Sources/Features/TodayFeature/Sources/TodayOrchestration.swift:138-143)
  The rollover branch clears child state but leaves `briefState` unchanged while immediately starting an asynchronous check-in gate. The accepted rationale calls this a one-frame window, but it lasts until `checkInRepository.current` returns and can be arbitrarily long or permanent if that dependency stalls. A prior-day `.ready` brief therefore remains mounted under today's header; forced-rest and nutrition content are derived directly from that old brief and remain visible even after the child reset.
  Recommendation: Synchronously replace or hide the old `briefState` with an honest rollover/loading state before starting asynchronous reads. Add a test that suspends the new-day gate from `.ready` and verifies prior-day content is no longer renderable.

Next steps:
- Implement day/generation-scoped save responses and test both race orderings.
- Hide prior-day brief content synchronously during rollover.
- Re-run and record the full validation suite after the post-validation a41c319 changes and these fixes.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | A save response crossing midnight without a scene re-activation stamps `lastSavedAt` with today's clock and fires the delegate, whose orchestration stamps `contentDay` to today — permanently masking the rollover | high | fix | Real and worse than the accepted D6 delay: it defeats even the NEXT activation's detection; fixed by carrying the persisted day key in `saveResponse.success` and dropping footer stamp + delegate on a stale day (spinner still clears) | 776a87a |
| 2 | Prior-day `.ready` brief remains renderable while the rollover's async gate check runs ("unbounded latency") | medium | reject | Explicitly accepted in validation round-1 #8 and recorded in PLAN.md Risks: the alternative invents a synthetic loading state outside the orchestration's ownership, and the window is one local GRDB read (`checkInRepository.current`), not an unbounded network call — the re-orchestration lands the full-screen `.checkInRequired` gate immediately after | |
