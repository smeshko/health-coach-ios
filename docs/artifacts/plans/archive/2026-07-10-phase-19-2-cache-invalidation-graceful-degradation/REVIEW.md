# Review Summary — phase-19-2-cache-invalidation-graceful-degradation

**Rounds:** 3
**Fix commits:** 29b8720..76ed2b0

## Rounds

| Round | Findings | Fixed | Deferred | Rejected |
|-------|----------|-------|----------|----------|
| 1     | 1        | 1     | 0        | 0        |
| 2     | 1        | 1     | 0        | 0        |
| 3     | 2        | 0     | 2        | 0        |

## Fixes

### Round 1
- `29b8720` — `runBackgroundPass` started `zones()` alongside `sync()`, so a watermark advance from that very sync was only picked up on the *next* pass; recomputed constants arrived one refresh cycle late on the cache-hit app-open / pull-to-refresh path. Added a post-sync `zones()` read on the success path (pre-sync read kept as the failure-path fallback per 12.1 D3 round-3 #2), pinned by `test_backgroundRefresh_syncOk_deliversPostSyncRecomputedZones` (round-1 #1)

### Round 2
- `76ed2b0` — the round-1 fix read post-sync zones only after `dailyBrief(true)` succeeded, so sync-ok + brief-fail still merged pre-sync zones. Restructured the pass: the post-sync read starts immediately after the successful sync, alongside the brief, and merges on both the resolved and failed-brief paths (pre-sync value only as nil fallback), pinned by `test_backgroundRefresh_syncOk_briefFails_deliversPostSyncRecomputedZones` (round-2 #1)

## Deferred

<!-- Findings worth doing later but out of scope here. Each becomes a follow-up suggestion in the PR body. -->

- (round-3 #1) Post-sync `zones()` read is awaited before the terminal background-refresh action, so a stalled `/profile` can hold the quiet "Updating…" pill past the brief resolution — bounded, not a hang: a stale profile whose refetch fails stale-serves after the APIClient retry window (D3), and the plan's Risks section explicitly accepts that network-attempt window. Follow-up polish: decouple zone hydration from the terminal refresh actions (new feature action; reworks 12.1 D3's merge-via-terminal-actions design). *(Linear not wired — recorded here.)*
- (round-3 #2) Pre-sync and post-sync zone reads can race into two `/profile` refetches in one pass (no single-flight guard in `ProfileRepository`) — only when the pre-sync read is itself a network fetch (profile already stale/missing at pass start) that outlasts the whole sync; worst case is one redundant small GET, and the stamp-with-pre-fetch-watermark rule guarantees the race can never mask a recompute. Follow-up hardening: single-flight/coalescing keyed by the observed watermark. *(Linear not wired — recorded here.)*

## Rejected

<!-- Findings we pushed back on. Surfaces what Codex flagged and why we said no, so PR reviewers see the reasoning. -->

- (none)
