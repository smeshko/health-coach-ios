# TASK-002: Undecodable cached profile degrades to a fresh fetch

Depends on: None
Suggested commit: `fix(profile): degrade an undecodable cached profile to a network fetch instead of a permanent brick`

## Goal

An undecodable `ProfileRecord` body no longer bricks `profile()`/`zones()` forever — the
row is deleted and the call converges to the plain first-fetch path (network → persist),
so the only remaining failure mode is the ordinary recoverable `fetchFailed`.

## Files

- `Package.swift` — add the `LogClient` interface dependency to the
  `ProfileRepositoryLive` target and to `ProfileRepositoryLiveTests` (validation
  round-1 #1); while editing that block, fix BOTH stale comments from the deleted
  recompute machinery (`b5eed33`): the Live block's "owns the recompute AsyncStream" and
  the interface block's "recompute stream" (~Package.swift:542) — round-1 #8 /
  round-2 #4.
- `Sources/Repositories/ProfileRepository/Live/ProfileRepository+Live.swift` —
  `fetchProfile()`: wrap the cache-hit `try cached.toDomain()` in do/catch; on decode
  failure, log the degradation on the always-on `.http` category, delete the singleton
  row (`ProfileRecord.deleteOne(db, key: 1)` inside a `database.write`), and fall
  through to the existing network-fetch-and-persist path (DECISIONS D2 — the profile
  deletes eagerly because the row's existence is what blocks the miss path).
- `Sources/Repositories/ProfileRepository/Tests/ProfileRepositoryLiveTests/ProfileCacheTests.swift`
  — seed `ProfileRecord(id: 1, constitutionVersion: "vX", body: Data("garbage".utf8))`:
  (a) `profile()` with a stubbed API → returns the fetched profile, row replaced (a
  second call serves cache, no network); (b) `profile()` with a failing API → throws
  `ProfileRepositoryError.fetchFailed` (not a `DecodingError`), and a subsequent call
  with a working API succeeds (no lingering corrupt row re-brick).

## Acceptance

- [ ] Corrupt profile + working API: fetch, persist, return; second call cache-hits with
  zero network.
- [ ] Corrupt profile + failing API: `fetchFailed` surfaces; the corrupt row is gone, so
  the next call is a clean miss that succeeds once the API does.
- [ ] A decode degradation logs one notice on `.http`.
- [ ] Existing `ProfileCacheTests` (hit/miss/error/mock) pass unchanged.

Evidence: ProfileRepositoryLiveTests suite output with the new corrupt-row tests green.

## Steps

### RED
- [ ] Add the two corrupt-row tests — today they fail with a propagating
  `DecodingError` (and the second call re-throws it forever).

### GREEN
- [ ] do/catch + `.http` log + delete + fall-through in `fetchProfile()`.

### REFACTOR
- [ ] Keep the miss path single-sourced (the catch falls into the same code the plain
  miss uses — no duplicated fetch/persist block).

## Notes

- Delete only on *decode* failure. A `database.read` throw keeps propagating (18.4
  discrimination: transient DB trouble is not row corruption).
