# Adversarial Review — Round 3

**Run:** 2026-07-10 17:35 UTC
**Branch:** fix/phase-19-2-cache-invalidation-graceful-degradation
**Base:** staging
**Commits reviewed:** 3602c0a..76ed2b0
**Prior rounds in scope:** reviews/round-1.md, reviews/round-2.md
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: the post-sync fix makes a slow `/profile` request hold the entire background refresh open, and its retained pre-sync read can race into duplicate profile fetches.

Findings:
- [medium] Post-sync zones request can leave background refresh spinning behind a stalled profile call (Sources/Features/TodayFeature/Sources/TodayOrchestration.swift:267-280)
  After every successful sync that advances the watermark, the post-sync `zones()` read must refetch the stale profile. Both the success and brief-failure paths await that task before sending the action that clears `isBackgroundRefreshing`. `/profile` uses the shared session with no path-level bound here, so a slow or stalled profile request keeps pull-to-refresh/background state active even after the brief has already resolved or failed. This is worse than the plan's accepted delayed zones chip: it delays completion of the whole quiet refresh.
  Recommendation: Send the brief terminal action without awaiting the optional post-sync zones fetch, then merge zones through a separate cancellable action/effect when it arrives; alternatively impose a short explicit timeout and fall back to the pre-sync zones. Add a test with a suspended post-sync `zones()` call proving the refresh flag clears promptly.
- [medium] Pre- and post-sync zone reads can issue two profile refetches for one refresh (Sources/Features/TodayFeature/Sources/TodayOrchestration.swift:253-271)
  The fix keeps an unawaited pre-sync `zones()` task and unconditionally starts another after sync. If the first task reaches `fetchProfile()` after the watermark advances (or is an in-flight miss when the second starts), both observe an unstamped/stale row before either save completes and both request `/profile`; the profile repository has no single-flight/coalescing guard. This violates the stated once-per-successful-sync refetch cadence and adds latency/load specifically during app-open and pull-to-refresh.
  Recommendation: Sequence the reads: fetch zones only after a failed sync for the fallback, and fetch them once after a successful sync. If overlapping reads are required, add single-flight/coalescing keyed by the observed watermark and a deterministic race test asserting one profile request per watermark advance.

Next steps:
- Restructure `runBackgroundPass` so zone hydration cannot block terminal background-refresh state and cannot start duplicate stale-profile fetches.
- Add controlled-suspension/race tests for the two paths before shipping.

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
| 1 | Post-sync `zones()` read is awaited before the terminal action, so a stalled `/profile` holds `isBackgroundRefreshing` (the quiet "Updating…" pill) past the brief resolution | med | defer | Cannot hang indefinitely: a stale profile whose refetch fails STALE-SERVES after the bounded APIClient retry window (D3), so the pill lingers at most that window in the narrow stalled-server-right-after-successful-sync case — the plan's Risks section explicitly accepts this network-attempt-before-stale-serve cost. Decoupling zone hydration from the terminal refresh actions needs a new feature action and reworks 12.1 D3's merge-via-terminal-actions design — follow-up polish, not a ship blocker. | |
| 2 | Pre-sync and post-sync zone reads can race into two `/profile` refetches for one pass (no single-flight guard in the repository) | med | defer | Requires the pre-sync read to itself be a network fetch (profile already stale/missing at pass start — not steady state, where it is a local cache hit) that outlasts the entire sync round-trip. Worst case is one redundant small GET and possibly one extra refetch on the next call — the stamp-with-pre-fetch-watermark rule (documented in `fetchProfile`) guarantees a race can never mask a recompute, so staleness converges with no correctness loss. Single-flight/coalescing in ProfileRepository is worthwhile hardening for a follow-up. | |
