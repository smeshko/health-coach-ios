# Adversarial Review — Round 3

**Run:** 2026-07-13 11:55 UTC
**Branch:** fix/phase-19-3-day-rollover-state-reset
**Base:** staging
**Commits reviewed:** 0dbd551..776a87a
**Prior rounds in scope:** reviews/round-1.md, reviews/round-2.md
**Reviewer:** Codex

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

Do not ship: 776a87a does not close the full save-to-orchestration race, continuously active scenes can still persist stale answers as today's, and rollover cancellation has another stale-state path.

Findings:
- [high] Day scoping is lost before the parent handles the save delegate (Sources/Features/TodayFeature/Sources/CheckInComponent.swift:165-175)
  The success handler validates `savedDay`, but then emits a separate day-less delegate action. If the response is reduced just before Sofia midnight and the delegate is processed after midnight, the parent recomputes today, stamps `contentDay` to the new day, and starts orchestration while yesterday's answers and footer remain. The next activation sees no mismatch, recreating the permanent rollover masking that 776a87a was intended to fix.
  Recommendation: Carry the saved day or an attempt generation through the delegate, revalidate it in the parent, and stamp orchestration from that validated value rather than a fresh clock read. Add a test that advances the clock between receiving `saveResponse` and receiving the delegate.
- [high] A continuously active scene can save yesterday's answers under today's key (Sources/Features/TodayFeature/Sources/TodayView.swift:116-120)
  Rollover is dispatched only when `scenePhase` changes to active; there is no event while the scene remains active across midnight. The first post-midnight save therefore builds a record using today's key from the still-resident yesterday answers. Its response passes the new same-day guard, and orchestration stamps `contentDay` to today, permanently preventing a later activation from resetting the stale state. A post-midnight retry from yesterday's terminal state has the same masking problem. This contradicts the plan's unqualified goal that resident state never carries yesterday's answers into today.
  Recommendation: Add a calendar-day boundary signal or centrally compare `contentDay` with today before every day-sensitive save/retry/orchestration action, resetting and re-gating before any write or stamp. Test `saveTapped` and `retryTapped` after midnight without `sceneBecameActive`.
- [high] Rollover cancellation is swallowed during selection restoration (Sources/Features/TodayFeature/Sources/TodayOrchestration.swift:46-49)
  Both orchestration factories wrap `sessionSelectionRepository.current(day)` in `try?` without checking cancellation afterward. If rollover cancels during that await, a thrown cancellation becomes `nil` and the old chain continues into `runBlockingChain`, which sends stale `_syncStarted` before checking cancellation. If the dependency ignores cancellation and returns, yesterday's `_selectionLoaded` can instead repopulate the reset state and race today's persisted selection or hydration.
  Recommendation: Handle `CancellationError` separately and check cancellation immediately after every awaited repository read and before every send. Day- or generation-scope selection responses as defense in depth, and suspend selection restoration across rollover in tests.
- [medium] The rejected stale-brief window remains latency-unbounded (Sources/Features/TodayFeature/Sources/TodayOrchestration.swift:132-143)
  The rollover branch resets children but leaves yesterday's `.ready` `briefState` mounted while `cacheFirstOpenEffect` awaits the new-day check-in read. Calling the dependency local does not bound its latency: the GRDB read can queue behind other database work or suspend. During that entire interval, forced-rest and nutrition content continue deriving directly from yesterday's brief beneath today's header. The triage rationale that this lasts one frame is not supported by the reducer.
  Recommendation: Synchronously hide or replace stale `briefState` with an explicit rollover/loading state before starting asynchronous reads. Add a test with a suspended new-day gate read and assert that prior-day ready content is no longer renderable.

Next steps:
- Fix and test the response-to-delegate midnight boundary.
- Guard post-midnight user actions when no scene transition occurs.
- Add suspended selection-restore and suspended gate-read rollover tests.
- Re-run the full validation suite after these concurrency fixes.

## Triage

Per protocol (round 3 with action rows), the user was consulted and chose **fix #2, then ship — no
round 4** (the finding stream had degraded: two of four findings are a factual error and a re-push).

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Day scoping lost between `saveResponse` and the delegate (midnight inside one store-queue drain) | high | fix | The window is a single synchronous action-queue drain (microseconds — not realistically exercisable on its own), but the #2 entry guard closes it for free: the delegate's orchestration entry now detects the stale stamp and resets | 159c2d2 |
| 2 | Continuously active scene: post-midnight save/retry enters orchestration and moves `contentDay` without a reset — yesterday's `restoredSelection` seeds today's carousel and the rollover is masked from all later activations | high | fix | Real residue verified RED (without the guard, the post-midnight save test hydrates selectedIndex 1 from yesterday's pick); fixed centrally with `rolloverGuardOnEntry` at the stamp write point in both factories, `sceneBecameActive`'s leg now delegates to it. The "user saves the visible answers under today's key" sub-point is user intent (an explicit Save tap) — a midnight observer stays out of scope per the plan (D6) | 159c2d2 |
| 3 | `try?` around `sessionSelectionRepository.current` swallows `CancellationError` → stale `_selectionLoaded`/`_syncStarted` sends | high | reject | Demonstrably incorrect: TCA's `Send.callAsFunction` guards `!Task.isCancelled` (Effect.swift:192) — a cancelled effect physically cannot deliver actions regardless of `try?`; the chain additionally does `try Task.checkCancellation()` after the gate read | |
| 4 | Stale-brief window "latency-unbounded" while the rollover gate check runs | medium | reject | Re-push of round-2 #2, unchanged grounding: explicitly accepted in validation round-1 #8 and recorded in PLAN.md Risks; the window is one local GRDB read and the alternative invents a synthetic loading state outside the orchestration's ownership | |
