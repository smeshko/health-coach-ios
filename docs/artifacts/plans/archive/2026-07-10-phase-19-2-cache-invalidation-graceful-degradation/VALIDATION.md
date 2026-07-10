# Validation Summary — phase-19-2-cache-invalidation-graceful-degradation

**Rounds:** 3 (reviewer: general-purpose subagent, adversarial framing — Codex usage-capped)
**Plan status at validation:** draft
**Run on:** 2026-07-10

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 8        | 7       | 1        | 0        |
| 2     | 5        | 5       | 0        | 0        |
| 3     | 2        | 0       | 1        | 1        |

## Applied

### Round 1
- PLAN.md:Scope, TASK-001, TASK-002 — `Package.swift` LogClient interface dependency for
  `BriefRepositoryLive`/`ProfileRepositoryLive` + test targets (the `.http` logging was
  unbuildable as planned) (round-1 #1)
- TASK-003 — `ProfileRecord(domain:)` `syncServerTime:` gets a `nil` default; the
  breaking call site named (round-1 #2)
- PLAN.md:Risks, RESEARCH.md — corrected the peek claim (TodayFeature already `try?`s
  it; the peek edit is policy-layer consistency + logging, not a feature behavior
  change) (round-1 #3)
- PLAN.md:Risks — stated the stale+offline behavior (network attempt + log per call
  until connectivity returns; accepted, narrow window) (round-1 #4)
- TASK-003 — pinned "stamp the pre-fetch watermark value; never re-read at write time"
  (mid-fetch sync would mask a recompute) (round-1 #5)
- TASK-003 — firmed the migration-test pattern (DomainBodyCacheMigrationTests exists);
  corrected the `test_cacheHit_noNetwork` claim (already the no-watermark case-(e)
  shape) (round-1 #6)
- TASK-002 — fold-in fix for the stale "recompute AsyncStream" Package.swift comment
  (round-1 #8)

### Round 2
- TASK-003 — the `nil` default is insufficient at runtime: GRDB persists nil optionals,
  so the pre-v5-schema seed in `DomainBodyCacheMigrationTests:39` must become a raw-SQL
  insert (grounded in GRDB source) (round-2 #1)
- TASK-001 — log assertion made mandatory via the guaranteed `LogRecorder` seam; hedge
  removed (round-2 #2)
- TASK-003 — "current watermark stamp" wording aligned with the pre-fetch pin
  (round-2 #3)
- TASK-002 — second stale recompute comment (interface block) folded in (round-2 #4)
- TASK-004 — epic AC-#1 tick annotation bullet added ("visible at the next successful
  sync") so the deferred round-1 #7 semantics survive into implementation (round-2 #5)

## Deferred

- (round-1 #7) Epic AC #1 satisfaction semantics ("new values at the next successful
  sync") — epic text left as-is; the semantics are carried by TASK-004's tick
  annotation (added in round-2 #5).
- (round-3 #1) Third stale recompute comment (`Package.swift:923`,
  ProfileRepositoryLiveTests block) — self-heals once TASK-003 lands (the suite will
  genuinely cover refetch-on-recompute); fold in only if already rewording that block.

## Rejected

- (round-3 #2) TASK-001's `$0.log = .recording(into:)` phrasing vs the suites'
  fixed-parameter helpers — imprecision that cannot mislead; the task already cites the
  safe-default property the trivial adaptation relies on.
