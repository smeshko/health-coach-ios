# Adversarial Review — Round 1

**Run:** 2026-07-13 11:15 UTC
**Branch:** fix/phase-19-3-day-rollover-state-reset
**Base:** staging
**Commits reviewed:** 0dbd551..7a746b7
**Reviewer:** Codex

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

Do not ship: the rollover reset is not an async barrier, so prior-day check-in work can corrupt the newly reset state.

Findings:
- [high] Prior-day check-in effects can undo the rollover reset (Sources/Features/TodayFeature/Sources/TodayOrchestration.swift:161-167)
  `rolloverReset` replaces `checkIn` state but neither cancels nor invalidates `CheckInComponent` effects already in flight. A pre-midnight `current(day)` can later repopulate yesterday's answers through `_currentLoaded`; a pre-midnight save can complete after reset, set `lastSavedAt` using the new day's clock, and emit `checkInSaved`, despite having persisted under yesterday's day key. The UI can consequently claim today's check-in was saved, seed yesterday's health answers, or start duplicate orchestration. The existing rollover tests seed an in-flight parent enum but do not exercise suspended child effects.
  Recommendation: Make check-in load/save responses day- or generation-scoped and ignore responses whose captured day no longer matches the active Sofia day. Also assign cancellable IDs to child effects and cancel them during rollover. Add tests that suspend both `current` and `save` across rollover and verify no stale state, footer, delegate, or orchestration is produced.

Next steps:
- Implement child-effect invalidation for rollover.
- Add suspended load/save race tests before merging.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Prior-day check-in load/save effects survive `rolloverReset` and can re-seed yesterday's answers, set `lastSavedAt` from today's clock, and fire a stale `checkInSaved` delegate | high | fix | Verified in code: both child effects are plain `.run` with no cancellable ID (CheckInComponent.swift:102/142), `rolloverReset` is pure state mutation, and CheckInSection.swift:66's "needs no day guard" comment is defeated by post-reset delivery — this defeats the phase's core guarantee ("yesterday's answers never carry into today"), doesn't contradict any Decision (D1–D4 cover reset placement, not effect invalidation) | a41c319 |
