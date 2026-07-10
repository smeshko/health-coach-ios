# Plan: Cache invalidation and graceful degradation

Status: done
Branch: fix/phase-19-2-cache-invalidation-graceful-degradation
Risk: medium
Epic: 19 — Make the numbers trustworthy (audit wave 2) ([epic](../../epics/19-trustworthy-numbers.md))
Phase: 19.2 — Cache invalidation and graceful degradation
Linear: none
Created: 2026-07-10

## Goal

Recomputed server constants (HR zones/thresholds) actually reach the device — the
profile cache goes stale after every successful sync and refetches — and an undecodable
cached row (profile, daily brief, weekly plan) degrades to a cache miss / fresh fetch
instead of bricking the whole Sofia-day or ISO-week period behind an unrecoverable Retry.

## Scope

- `Sources/Repositories/BriefRepository/Live/DailyBriefPolicy.swift` — decode failure in
  the non-refresh cache branch (and the `cachedDailyBriefPolicy` peek) treated as a miss.
- `Sources/Repositories/BriefRepository/Live/WeeklyPlanPolicy.swift` — same for the
  weekly non-refresh cache branch (there is no weekly peek).
- `Sources/Repositories/ProfileRepository/Live/ProfileRepository+Live.swift` —
  undecodable cached profile → delete + network fetch; sync-anchored staleness so a
  constants recompute causes a refetch.
- `Sources/Models/PersistenceModels/Sources/ProfileRecord.swift` +
  `Sources/Clients/Database/Sources/Migrations.swift` — additive `syncServerTime` column
  (migration `v5`) stamping which sync the cached profile was fetched under.
- Decode-failure logging on the always-on `.http` category (audit-critical failure
  records — Epic-18 convention; `.app` is toggle-gated).
- `Package.swift` — add the `LogClient` interface dependency to `BriefRepositoryLive`,
  `ProfileRepositoryLive`, and their test targets (validation round-1 #1; follows the
  Database/SyncRepositoryLive precedent — neither target imports LogClient today, so the
  logging above would not build otherwise).
- Corrupt-row tests at the existing repository test seams (in-memory GRDB, raw SQL row
  seeding).

## Out of Scope

- Decoding `SyncResponse.recomputeOk` (the poison-day brief self-heal signal) — that is
  wire-contract drift repair for *brief* staleness, not named by Phase 19.2; the sync-
  anchored profile staleness here needs no new wire field. Candidate follow-up alongside
  Epic 20's contract work.
- Day-rollover state reset (Phase 19.3), backend invariants/persistence (19.4/19.5).
- Any backend change; any change to the cache-first read order itself (D23 stands:
  cached-first, no network on a fresh hit — staleness only widens when the *profile*
  refetches, it never blocks brief/plan serving).
- Retry-affordance UI changes — with decode-degradation in place the existing Retry
  becomes able to succeed; no new UI.

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing findings:

- `ProfileRecord`'s own doc comment documents the missing behavior ("refreshed when the
  server recomputes constants") — but `fetchProfile()` is cache-first with **no**
  invalidation path at all; the old recompute machinery (`refresh()`, `noteRecompute()`,
  `RecomputeStream`) was deleted as zero-subscriber in `b5eed33`.
- All cached bodies decode via `DomainBodyCoder` (`JSONDecoder`) in `toDomain()`, which
  throws on corruption/format drift. `dailyBriefPolicy` (cache branch), the
  `cachedDailyBriefPolicy` peek, `weeklyPlanPolicy` (cache branch), and `fetchProfile()`
  all propagate that throw. Features map it to their error state; Retry re-enters the
  same cache branch → the same throw, forever (the brick).
- The watermark row (`SyncWatermarkRecord`, singleton id=1) carries `serverTime` — the
  server's own clock, updated on every successful sync. Stamping the profile row with
  the watermark `serverTime` visible at fetch time gives a clock-skew-free staleness
  test: profile is stale iff its stamp differs from the current watermark `serverTime`.
- Migrations are at `v4_createSessionSelection`; additive `alter table` is the
  established pattern (`v2`). A nullable new column means pre-upgrade rows read as
  "stale once" — exactly the desired backfill behavior.
- Existing tests cover cache hit/miss/sync-gate/API-error paths (`ProfileCacheTests`,
  `DailyCachePolicyTests`, `WeeklyCachePolicyTests`) but seed only valid rows — zero
  corrupt/undecodable coverage. In-memory GRDB allows raw SQL inserts to seed garbage
  `body` blobs.
- Blast radius of profile changes: `TodayFeature`/`WeeklyFeature` already treat a zones
  throw as non-fatal (render without the chip/row), so profile-path changes cannot brick
  those screens; the brief/plan policies are the brick-capable paths.

## Decisions

See [DECISIONS.md](./DECISIONS.md) — D1 sync-anchored staleness vs TTL vs recomputeOk
plumbing; D2 decode-failure handling semantics (miss + overwrite, delete only for
profile); D3 stale-serve on refetch failure.

## Risks

- Profile now refetches once per sync — a device that syncs daily makes one extra small
  `GET /profile` per day; offline-after-sync serves the stale cached profile (D3), so
  availability is unchanged.
- Clock skew — avoided by design: staleness compares two copies of the *server's* clock
  (watermark `serverTime` vs the stamped `syncServerTime`), never the device clock.
- Migration `v5` on existing installs — additive nullable column; NULL reads as stale →
  one refetch after upgrade, then steady state. No cache clear, no data loss.
- A corrupt daily/weekly row whose regenerate path hits `.syncRequired` still throws
  that (correct — the gate stands); the corrupt row is only overwritten when generation
  succeeds. Tests pin that the error is now `.syncRequired` (recoverable, sync fixes
  it), not a decode error.
- `cachedDailyBriefPolicy` peek returning `nil` on corruption is a policy-layer
  consistency + logging change only — `TodayFeature` already wraps the peek in `try?`
  (corruption reads as `nil` at the feature today), so no feature behavior changes
  (validation round-1 #3).
- Stale profile + unreachable server (sync succeeded, then offline before the refetch):
  every `profile()`/`zones()` call attempts the network — including the APIClient
  retry/backoff window — before stale-serving, with one `.http` error log per attempt.
  Accepted by design (the window is narrow: the device was online for the sync seconds
  earlier); the cost is zones-chip latency and log chatter until connectivity returns
  (validation round-1 #4).

## Acceptance Criteria

- [x] After a successful sync advances the watermark `serverTime`, the next
  `profile()`/`zones()` call refetches from the network and stamps the new
  `serverTime`; with an unchanged watermark it serves the cache with no network call
  (pinned by `ProfileCacheTests` additions).
  *(ProfileCacheTests: `test_watermarkAdvances_refetchesOnceAndRestamps_thenSteadyState`
  — refetch once, restamp, then zero-network steady state;
  `test_freshStamp_matchingWatermark_cacheServes_noNetwork` — all passed on sim
  2026-07-10.)*
- [x] An undecodable cached profile body degrades to a network fetch (row replaced on
  success); if the network also fails, the error is the existing
  `ProfileRepositoryError.fetchFailed` — never a raw `DecodingError`.
  *(ProfileCacheTests: `test_corruptCachedProfile_workingAPI_refetchesAndReplaces`
  — second call cache-hits with zero network;
  `test_corruptCachedProfile_failingAPI_throwsFetchFailed_thenRecovers`.)*
- [x] A corrupt `DailyBriefRecord` row is treated as a cache miss by both
  `dailyBriefPolicy(refresh: false)` (regenerates and overwrites) and the
  `cachedDailyBriefPolicy` peek (returns `nil`); a corrupt `WeeklyPlanRecord` row is
  treated as a miss by `weeklyPlanPolicy` — the period is never bricked behind a decode
  error.
  *(DecodeDegradationTests: `test_dailyBrief_corruptRowSynced_regeneratesAndOverwrites`,
  `test_cachedDailyBrief_corruptRow_returnsNil_noNetwork`; WeeklyCachePolicyTests:
  `test_weeklyBrief_corruptRowSynced_regeneratesAndOverwrites`.)*
- [x] When the regenerate path is sync-gated, a corrupt row surfaces `.syncRequired`
  (recoverable), not a decode error.
  *(`test_dailyBrief_corruptRowUnsynced_throwsSyncRequired` +
  `test_weeklyBrief_corruptRowUnsynced_throwsSyncRequired`.)*
- [x] Every decode-degradation event logs a notice on the always-on `.http` category.
  *(All four corrupt-row tests assert exactly one `.notice` on `.http` via LogRecorder —
  daily branch, daily peek, weekly branch, profile.)*
- [x] Migration `v5_addProfileSyncServerTime` is additive; a pre-upgrade profile row
  (NULL stamp) reads as stale exactly once, then steady-states.
  *(ProfileSyncStampMigrationTests:
  `test_v5_addsSyncServerTimeColumn_preservesProfileRow_idempotent`; ProfileCacheTests:
  `test_nullStamp_preUpgradeRow_staleExactlyOnce`.)*
- [x] All package tests green on the canonical sim; no snapshot changes expected.
  *(2026-07-10: full `xcodebuild test` on iPhone 17 Pro / OS 26.0 — 618 tests, 132
  suites, ** TEST SUCCEEDED **, all snapshot suites passed with zero re-records
  (working tree clean); `swiftlint --strict` — 0 violations in 386 files. Sim smoke same
  day: fresh Debug build launched, no crash/fault in app log.)*

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: Brief and weekly cache policies treat decode failure as a cache miss
- [x] TASK-002: Undecodable cached profile degrades to a fresh fetch
- [x] TASK-003: Sync-anchored profile staleness so recomputed constants reach the device
- [x] TASK-004: Final Validation
