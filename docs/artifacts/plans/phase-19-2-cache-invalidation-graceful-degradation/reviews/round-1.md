# Adversarial Review — Round 1

**Run:** 2026-07-10 17:12 UTC
**Branch:** fix/phase-19-2-cache-invalidation-graceful-degradation
**Base:** staging
**Commits reviewed:** 3602c0a..e2f8c3c
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: the primary background-refresh flow can consume the old profile before sync advances the watermark, so recomputed zones are not delivered in that refresh cycle.

Findings:
- [high] Pre-sync zones read bypasses the new invalidation (Sources/Repositories/ProfileRepository/Live/ProfileRepository+Live.swift:48-61)
  A cache hit returns immediately when the stored stamp equals the watermark read at the start of this function. The existing Today background-refresh path starts `profileRepository.zones()` concurrently before awaiting `syncRepository.sync()`, then uses that zones result after sync. Therefore a cached old profile can be returned under watermark W1, sync can successfully advance the watermark to W2/recompute constants, and the UI still receives the W1 zones with its refreshed brief. No post-sync profile read is forced, so the core guarantee that recomputed constants reach the device after sync is missed on this normal path.
  Recommendation: Sequence the Today background refresh so `zones()` runs after a successful sync, or explicitly issue a post-sync profile/zones read before publishing the refreshed UI. Add an integration test with a fresh cached profile and a sync that advances `serverTime`, asserting the emitted zones are the recomputed values.

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
| 1 | `runBackgroundPass` starts `zones()` before `sync()`, so a watermark advance from that very sync is only picked up on the *next* pass — recomputed constants arrive one refresh cycle late on the most common (cache-hit app-open / pull-to-refresh) path | high | fix | Confirmed against `TodayOrchestration.swift:249` — real gap in the phase Goal ("recomputed constants reach the device"); the blocking chain and WeeklyFeature already read zones post-sync/no-sync so only this pass is affected. Fix keeps the pre-sync read as the failure-path fallback (preserves 12.1 D3 round-3 #2: cached zones survive a failing sync) and adds a post-sync read on the success path, pinned by an orchestration test. | 29b8720 |
