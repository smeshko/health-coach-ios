# Decisions: Cache invalidation and graceful degradation (Phase 19.2)

## D1 — Profile staleness is sync-anchored (watermark `serverTime` stamp), not TTL and not recomputeOk plumbing

**Options weighed:**
1. **Sync-anchored stamp** — `ProfileRecord` gains a nullable `syncServerTime` column;
   at fetch time the row is stamped with the current watermark `serverTime`; a cached
   profile is stale iff its stamp differs from the current watermark `serverTime`
   (refetch, restamp).
2. **Wall-clock TTL** — refetch when the row is older than N hours.
3. **Decode `SyncResponse.recomputeOk` and invalidate on it** — plumb the wire field
   through `SyncResponse`/`SyncResult`/`SyncRepository` and have sync invalidate the
   profile row.

**Chosen: 1.** Rationale:
- Staleness compares two copies of the **server's** clock (the watermark `serverTime`
  the device saw at profile-fetch time vs the current one) — pure equality, immune to
  device-clock skew, no new wire fields.
- Refetch cadence is exactly "once per successful sync" (~daily) — the tightest window
  in which a server-side constants recompute can become visible, at the cost of one
  small `GET /profile` per sync.
- TTL (option 2) mixes device and server clocks, refetches when nothing changed, and can
  still miss a recompute for the whole TTL.
- Option 3's `recompute_ok` is the wrong signal: it reports the post-ingest
  *daily-metrics* recompute outcome (poison-day self-heal for briefs), defaults `True`,
  and says nothing about a monthly constants/zones re-derivation. Plumbing it is real
  contract-drift repair but belongs with the brief-staleness/openapi work (Epic 20
  candidate), not here.

## D2 — Decode failure = cache miss; only the profile deletes its row eagerly

**Options weighed:**
1. **Fall through to the fetch/generate path and let the success overwrite the corrupt
   row** (daily/weekly: `save` upserts the same PK; profile: `save` on id=1).
2. **Delete the corrupt row immediately, then fall through.**

**Chosen: 1 for daily/weekly, 2 for profile.** Rationale: the daily/weekly regenerate
path is sync-gated — if it throws `.syncRequired` the corrupt row lingers, but every
subsequent call still treats it as a miss (the degradation is in the read, not the row),
and a successful generation overwrites the PK; deleting early would only lose the
`fetchCount > 0` "has prior brief" signal used for API-error mapping. The profile is a
singleton whose *existence* is what blocks the miss path — deleting the undecodable row
makes the repository converge to the plain first-fetch state, and if the network fetch
then fails the next call retries cleanly. The peek (`cachedDailyBriefPolicy`) returns
`nil` on decode failure — a peek reports "no usable cache", it never repairs.

## D3 — Stale profile serves the cache when the refetch fails

A *stale* (but decodable) profile with an unreachable server serves the cached value —
freshness never buys an outage: zones that are one recompute old beat no zones. Only an
*undecodable* profile escalates to the network as its sole source (D2), because there is
nothing usable to serve. Failure ordering pinned by tests: stale + refetch-fails →
cached values; undecodable + fetch-fails → `ProfileRepositoryError.fetchFailed`.
