# Adversarial Review — Round 1

**Run:** 2026-07-10 09:55 UTC
**Branch:** fix/phase-18-2-bounded-hk-reads
**Base:** staging
**Commits reviewed:** 071ae25..517267c
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: cancellation can still allow a sync POST and watermark write after the user cancels.

Findings:
- [high] Cancellation race can persist a sync after Cancel (Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift:70-76)
  If `deltaSamples` completes as cancellation arrives, the operation task can claim and resume success first. `runSync` then continues into check-in reads, `/sync`, and the watermark write without checking cancellation. The later cancellation only marks `SyncTimeoutState` cancelled; it does not stop those side effects. This violates the intended no-POST/no-watermark cancellation path and can overlap a newly started sync despite the repository having no concurrency guard. The existing test only cancels while the read is definitely still blocked.
  Recommendation: Check cancellation immediately after the bounded read and before each irreversible boundary (especially API POST and database write), and add a deterministic test that races cancellation with a successfully completing delta read and asserts no POST or watermark mutation.

Next steps:
- Fix the cancellation-to-side-effect race and add coverage before shipping.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Cancellation racing a successfully-completing delta read lets `runSync` continue into the POST + watermark write in a cancelled task | high | fix | Verified in code: `SyncTimeoutState.resume(.success)` can claim before `cancel()`, and nothing downstream checks `Task.isCancelled` (the check-in read even swallows `CancellationError` via `try?`) — violates the plan's no-POST-after-cancel acceptance criterion | 3ff5d5d |
