# TASK-003: Sync-anchored profile staleness so recomputed constants reach the device

Depends on: TASK-002
Suggested commit: `feat(profile): sync-anchored profile staleness — refetch once per successful sync so recomputed constants reach the device`

## Goal

A server constants recompute reaches the device without a reinstall: the cached profile
is stamped with the watermark `serverTime` seen at fetch time and goes stale as soon as
a successful sync advances it — the next `profile()`/`zones()` call refetches and
restamps; a failed refetch stale-serves the cached values (DECISIONS D1/D3).

## Files

- `Sources/Models/PersistenceModels/Sources/ProfileRecord.swift` — add
  `public var syncServerTime: Date?` (nullable; kept in `init(id:constitutionVersion:body:syncServerTime:)`
  with a `nil` default so existing call sites compile); `init(domain:)` gains a
  `syncServerTime: Date? = nil` parameter (keeps other call sites compiling; no hidden
  dependency reads inside PersistenceModels).
- `Sources/Clients/Database/Tests/DomainBodyCacheMigrationTests.swift` (validation
  round-2 #1): the `nil` default is NOT enough for line 39 — GRDB overrides
  `encodeIfPresent`, so a nil optional still enters the persistence container and the
  INSERT names the `syncServerTime` column, which does not exist at the test's
  `migrate(upTo: "v2_…")` point → runtime "no column named syncServerTime". Convert
  that seed to a raw-SQL insert pinned to the pre-v5 schema (body bytes via
  `try ProfileRecord(domain: profileDomain).body`), like the test's other seeds.
- `Sources/Clients/Database/Sources/Migrations.swift` — additive
  `v5_addProfileSyncServerTime`: `alter table profile add column syncServerTime
  .datetime` (nullable — pre-upgrade rows read `nil` = stale exactly once; follows the
  `v2` additive pattern; no cache clear).
- `Sources/Repositories/ProfileRepository/Live/ProfileRepository+Live.swift` —
  `fetchProfile()`:
  1. Read the cached row AND the watermark (`SyncWatermarkRecord.fetchOne(db, key: 1)`)
     in one `database.read`.
  2. Decodable cached row with `cached.syncServerTime == watermark?.serverTime` (both
     nil-equal only when both nil) → serve, no network (the fresh-hit path, unchanged
     cost). Note: no watermark (never synced) + stamped row cannot happen in practice,
     but equality handles it.
  3. Stale (stamp differs, incl. `nil` stamp) → refetch `GET /profile`; on success
     persist with `syncServerTime = watermark?.serverTime` and return; on failure
     stale-serve the decoded cached profile (D3 — availability unchanged).
  4. Miss/undecodable paths (TASK-002) persist with the step-1 (pre-fetch) watermark
     value too — see Notes; never a re-read at write time.
- `Sources/Repositories/ProfileRepository/Tests/ProfileRepositoryLiveTests/ProfileCacheTests.swift`
  — new cases: (a) stamped row + unchanged watermark → cache serve, zero network; (b)
  advance the watermark `serverTime` (seed a new `SyncWatermarkRecord`) → next
  `profile()` hits the API and restamps (a third call cache-serves again); (c) stale +
  API failure → returns the *cached* profile values (stale-serve), no throw; (d) NULL
  stamp (pre-upgrade row) → treated as stale once; (e) never-synced DB (no watermark
  row) + unstamped cached row → serves cache, no network.
- Existing tests: `test_cacheHit_noNetwork` seeds a cached row and **no watermark**
  (ProfileCacheTests:71–83) — that is already exactly case (e) and passes unchanged
  (validation round-1 #6); do not rewrite it, just let (e) reference/extend it if
  convenient.
- Migration test: follow the existing `DomainBodyCacheMigrationTests` pattern
  (`migrate(queue, upTo:)` → seed old-shape row → full `migrate()` → assert) to pin v5's
  additive behavior on a pre-upgrade profile row (round-1 #6 — the pattern exists; no
  hedging).

## Acceptance

- [ ] Fresh hit (stamp == watermark serverTime): zero network.
- [ ] After the watermark advances: exactly one refetch, new values returned and
  persisted, then steady-state cache serves.
- [ ] Stale + refetch failure: cached values served (no error, no availability loss).
- [ ] NULL-stamp upgrade row: one refetch, then steady state.
- [ ] Migration `v5` is additive and idempotent (migrator identifier recorded); no
  existing-row data loss — pinned by a migration test if the Database test target has
  the pattern, else by the upgrade-row test in (d).

Evidence: ProfileRepositoryLiveTests output for (a)–(e); migration listed in
`Migrations.swift` with the additive pattern.

## Steps

### RED
- [ ] Add tests (a)–(e) — (b)/(c)/(d) fail against today's never-invalidated cache.

### GREEN
- [ ] Column + migration + the staleness/stale-serve logic in `fetchProfile()`.

### REFACTOR
- [ ] Single read for row+watermark (no second read race); comment WHY the stamp is the
  server clock (skew-free equality, D1).

## Notes

- Do not compare with `<`/`>` — equality only. `serverTime` is the server's clock; the
  device never generates it, so "differs" is the exact staleness predicate and ordering
  assumptions buy nothing.
- **Stamp the watermark value read BEFORE the network fetch (the step-1 single read);
  never re-read the watermark at write time** (validation round-1 #5): a sync completing
  mid-`GET /profile` would otherwise stamp a possibly pre-recompute profile with the new
  `serverTime` and mask the recompute until the following sync. Stamping the pre-fetch
  value costs at most one redundant refetch and can never mask.
- `zones()` needs no change (it is `fetchProfile().zones`).
- Mock `ProfileRepository` and DevMenu routing are untouched — the staleness lives
  entirely inside the live `fetchProfile()`.
