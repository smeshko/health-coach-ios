# Research: Cache invalidation and graceful degradation (Phase 19.2)

Curated findings, 2026-07-10. Sources: audit `docs/artifacts/audits/AUDIT-2026-07-05.md`,
code reads of ProfileRepository/BriefRepository Live + PersistenceModels + Database
migrations, backend `app/api/schemas/sync.py`.

## Key Files

- `Sources/Repositories/ProfileRepository/Live/ProfileRepository+Live.swift` —
  `fetchProfile()`: cache-first singleton read (`ProfileRecord.fetchOne(db, key: 1)`);
  a hit returns `try cached.toDomain()` (unguarded decode throw); a miss fetches
  `GET /profile` and persists. **No invalidation path of any kind.** API errors map to
  `ProfileRepositoryError.fetchFailed(reason:)`.
- `Sources/Repositories/BriefRepository/Live/DailyBriefPolicy.swift` —
  `dailyBriefPolicy(refresh:)`: non-refresh branch returns `try cached.toDomain()`
  (line ~28, unguarded); `cachedDailyBriefPolicy()` peek (line ~63) same. Regenerate
  path is sync-gated (`requireSyncedWatermark()` → `.syncRequired`).
- `Sources/Repositories/BriefRepository/Live/WeeklyPlanPolicy.swift` —
  `weeklyPlanPolicy(isoWeek:refresh:)`: non-refresh branch `try cached.toDomain()` then
  stamps `domain.cached = true` (line ~40, unguarded). No weekly peek exists
  (`cachedDailyBrief` is the only peek on `BriefRepository`).
- `Sources/Models/PersistenceModels/Sources/ProfileRecord.swift` — singleton (id=1),
  columns `id`, `constitutionVersion`, `body: Data`; doc comment: "refreshed when the
  server recomputes constants" — the documented-but-missing invalidation. `toDomain()`
  = `DomainBodyCoder.decode` (throws).
- `Sources/Models/PersistenceModels/Sources/DomainBodyCoder.swift` — plain
  `JSONDecoder`; corruption/format drift → `DecodingError`.
- `Sources/Models/PersistenceModels/Sources/DailyBriefRecord.swift` (PK `date`, Sofia
  midnight) / `WeeklyPlanRecord.swift` (PK `isoWeek` string) — `body: Data` blobs, same
  coder, same throw.
- `Sources/Models/PersistenceModels/Sources/SyncWatermarkRecord.swift` — singleton
  (id=1) with `serverTime: Date` = the server's clock from the last successful sync
  response; advanced by `SyncRepository.runSync` step 7 on success only.
- `Sources/Clients/Database/Sources/Migrations.swift` — registered:
  `v1_createCachedEntities`, `v2_addLastStrengthTestSyncedWeek` (additive alter-table
  pattern), `v3_clearDomainBodyCaches`, `v4_createSessionSelection`. Next: `v5`.

## History / architecture facts

- Commit `b5eed33` "refactor(profile): delete the zero-subscriber recompute machinery"
  removed `refresh()`, `recomputeNotices()`, `noteRecompute()`, `RecomputeStream` — the
  original recompute-driven profile refresh. Nothing replaced it.
- Backend `SyncResponse` (backend `app/api/schemas/sync.py` ~155–175) carries
  `recompute_ok: bool = True` — the post-ingest daily-metrics recompute outcome. iOS
  `WireModels.SyncResponse` does **not** decode it (audit contract-drift finding); the
  domain `SyncResult` lacks it too. It is a *brief/poison-day* signal, not a constants
  signal — not needed for profile staleness (see DECISIONS D1) and left out of scope.
- Features degrade zones gracefully already: `TodayFeature`/`WeeklyFeature` fetch zones
  concurrently and treat a throw as `nil` (chip/row simply not rendered). The
  brick-capable paths are the brief/plan policies, whose decode throw lands in the
  features' error states → Retry re-enters the same cache branch → same throw (the
  unrecoverable Retry from the audit).

## Error propagation (the brick, precisely)

1. Corrupt `DailyBriefRecord` for today → `dailyBriefPolicy(false)` throws
   `DecodingError` from the cache branch (never reaches the network) → TodayFeature
   error state → Retry calls the same policy → same row → same throw. The whole Sofia
   day is bricked. Same shape for the ISO week via `weeklyPlanPolicy`. (The
   `cachedDailyBriefPolicy` *peek* is NOT a brick path: `TodayFeature` already wraps it
   in `try?` — corruption reads as `nil` at the feature today. The peek edit in this
   plan is policy-layer consistency + the `.http` log line, not a feature behavior
   change — validation round-1 #3.)
2. Corrupt `ProfileRecord` → `profile()`/`zones()` throw forever; zones degrade in the
   features, but the profile can never heal without reinstall (delete-app) because the
   miss path (fetch+persist) is unreachable while the row exists.

## Test seams

- All three repos test against in-memory GRDB (`DatabaseClient.makeInMemory()`), stub
  `apiClient` closures, and `LockIsolated` capture (`ProfileCacheTests`,
  `DailyCachePolicyTests` ~282 lines, `WeeklyCachePolicyTests` ~187 lines,
  `PostUpgradeCacheClearTests` for v3's cache clear).
- No existing test seeds a corrupt row. Seeding garbage: raw SQL insert
  (`db.execute(sql:)`) or constructing the record memberwise with `body: Data("junk")` —
  `ProfileRecord.init(id:constitutionVersion:body:)` is public; daily/weekly records
  have equivalent memberwise inits.
- Watermark seeding pattern exists in SyncRepository tests
  (`SyncWatermarkRecord(anchor:serverTime:)` saved directly).

## Useful Commands

```bash
make test    # host suite
xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace -scheme CoachKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'   # sim gate
```

## Uncertainty

- Whether `GET /profile` responses carry any server timestamp usable as a staleness
  anchor — not relied on: the watermark `serverTime` (already persisted, already
  server-clock) is the anchor, so no wire change is needed.
- Exact `WeeklyFeature` repo-freshness interplay (Epic 20 Phase 20.3 owns weekly-tab
  reliability) — this phase only changes what a corrupt weekly row yields at the policy
  layer (miss instead of throw), which is strictly less surprising for the feature.

## References

- `docs/artifacts/audits/AUDIT-2026-07-05.md` — profile-cache-never-invalidated and
  undecodable-row-bricks-period findings; recomputeOk contract drift.
- ARCHITECTURE §7 cache-first policy (D23) — read order unchanged by this phase.
