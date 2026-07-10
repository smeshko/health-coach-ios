# Adversarial Review — Round 2

**Run:** 2026-07-10 17:26 UTC
**Branch:** fix/phase-19-2-cache-invalidation-graceful-degradation
**Base:** staging
**Commits reviewed:** 3602c0a..29b8720
**Prior rounds in scope:** reviews/round-1.md
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: the round-1 fix only delivers recomputed zones when the subsequent brief refresh succeeds; a successful sync followed by a brief failure still publishes pre-sync zones.

Findings:
- [high] Post-sync zones are skipped when the brief refresh fails (Sources/Features/TodayFeature/Sources/TodayOrchestration.swift:258-269)
  The new post-sync `zones()` call is ordered after `dailyBrief(true)`. If sync successfully advances the watermark but the brief request throws, control jumps to the catch and sends only `preSyncZones`. That leaves user-visible HR zones at their pre-sync values despite the successful sync and suppresses an immediate retry by recording the successful sync. This is the same cache-invalidation guarantee round 1 required, but an ordinary partial-failure path still misses it.
  Recommendation: Start the post-sync zones fetch immediately after successful sync, alongside the brief request, and merge its result on both the resolved and failed-brief paths (falling back to pre-sync zones only if that fetch has no value). Add a test where sync advances zones and `dailyBrief(true)` throws, asserting `_backgroundRefreshFailed` receives the recomputed zones.

Next steps:
- Fix the partial-failure path and add the targeted regression test before shipping.

## Triage

<!--
Verdict values:
  fix    — real bug; address now in this branch
  defer  — has merit but out of scope; capture as a follow-up
  reject — contradicts an explicit Decision in PLAN.md, or is taste/speculation

One row per finding. Number them so subsequent rounds can reference them
(e.g. "round-1 #3 is unaddressed"). Severity is one of: high, med, low.
Commit is the fix SHA when verdict is `fix`; empty otherwise.
-->

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Round-1 fix reads post-sync zones only after `dailyBrief(true)` succeeds — sync-ok + brief-fail jumps to the catch and merges pre-sync zones, so recomputed constants still miss the partial-failure path | high | fix | Correct — a real gap in the round-1 fix. Restructured `runBackgroundPass`: post-sync `zones()` starts as an `async let` immediately after the successful sync and merges on BOTH the resolved and failed-brief paths (pre-sync value only as nil fallback); a failing sync (watermark unmoved) still returns the pre-sync cached zones per 12.1 D3 round-3 #2. Pinned by `test_backgroundRefresh_syncOk_briefFails_deliversPostSyncRecomputedZones`. | 76ed2b0 |
