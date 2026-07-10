# TASK-001: Brief and weekly cache policies treat decode failure as a cache miss

Depends on: None
Suggested commit: `fix(brief): treat an undecodable cached brief/plan row as a cache miss instead of bricking the period`

## Goal

A corrupt/format-drifted `DailyBriefRecord` or `WeeklyPlanRecord` no longer bricks the
Sofia day / ISO week behind an unrecoverable Retry — the non-refresh cache branches and
the daily peek treat a `toDomain()` throw as a miss and proceed (regenerate / return
nil).

## Files

- `Package.swift` — add the `LogClient` interface dependency to the
  `BriefRepositoryLive` target and to `BriefRepositoryLiveTests` (validation round-1
  #1 — neither depends on LogClient today; follow the Database/SyncRepositoryLive
  precedent).
- `Sources/Repositories/BriefRepository/Live/DailyBriefPolicy.swift` —
  - `dailyBriefPolicy(refresh:)` non-refresh branch: `do { return try cached.toDomain() }
    catch { log decode-degradation on .http; fall through to the generate path }`. The
    corrupt row is overwritten by the successful `save` (same `date` PK, DECISIONS D2);
    if generation is sync-gated, `.syncRequired` surfaces (recoverable).
  - `cachedDailyBriefPolicy()` peek: decode throw → log + return `nil` (a peek reports
    "no usable cache"; it never generates or repairs).
- `Sources/Repositories/BriefRepository/Live/WeeklyPlanPolicy.swift` — same fall-through
  in the non-refresh branch (the `domain.cached = true` stamping stays on the success
  path only).
- `Sources/Repositories/BriefRepository/Tests/BriefRepositoryLiveTests/DailyCachePolicyTests.swift`
  (or a new `DecodeDegradationTests.swift` beside it if the file nears the 400-line cap) —
  seed a same-day row with garbage `body` (memberwise `DailyBriefRecord` init or raw
  SQL): (a) `dailyBriefPolicy(false)` with synced watermark + stubbed API → regenerates,
  returns the fresh brief, row overwritten (subsequent cached read decodes); (b) with
  UNsynced watermark → throws `.syncRequired`, not a `DecodingError`; (c)
  `cachedDailyBriefPolicy()` → `nil`, no network.
- `Sources/Repositories/BriefRepository/Tests/BriefRepositoryLiveTests/WeeklyCachePolicyTests.swift`
  — same (a)/(b) shape for a corrupt `WeeklyPlanRecord` under the current ISO week.

## Acceptance

- [ ] Corrupt daily row + synced watermark: `dailyBriefPolicy(false)` calls the API,
  persists, returns fresh domain; a second call serves the (now valid) cache with no
  further network.
- [ ] Corrupt daily row + no sync: throws `.syncRequired` (recoverable), never a decode
  error.
- [ ] Peek on a corrupt row: `nil`, zero network calls.
- [ ] Corrupt weekly row: regenerates and overwrites under the same `isoWeek` key.
- [ ] Each degradation logs one notice on `.http`, asserted via the existing LogClient
  recorder seam (`LogRecorder` / `.recording(into:)` from `LogClient+TestValue.swift` —
  the test-target dependency added in this task guarantees it; inject with
  `$0.log = .recording(into:)` in the existing `withDependencies` setup). No code-review
  escape hatch (validation round-2 #2).

Evidence: BriefRepositoryLiveTests suite output with the new corrupt-row tests green.

## Steps

### RED
- [ ] Add the corrupt-row tests — they fail today with `DecodingError` propagating out
  of the cache branch.

### GREEN
- [ ] Wrap the three `toDomain()` call sites in do/catch with the miss fall-through /
  nil, plus the `.http` log line.

### REFACTOR
- [ ] Keep the catch narrow (log + degrade only — no error swallowing on the network or
  DB paths); confirm the existing hit/miss/gate tests still pass unchanged.

## Notes

- Do NOT catch around `database.read` itself — a DB *read* failure is not corruption of
  one row and must keep propagating (Phase 18.4 discrimination philosophy).
- The `fetchCount > 0` "has prior brief" signal used in API-error mapping still counts
  the corrupt row — deliberate (DECISIONS D2): the user *had* a brief; the 500-fork
  copy should not regress to first-ever.
