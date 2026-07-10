# Adversarial Validation — Round 1

**Run:** 2026-07-10
**Reviewer:** subagent (general-purpose, adversarial framing — Codex usage-capped)
**Plan:** phase-19-2-cache-invalidation-graceful-degradation
**Status at start:** draft

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

## Verdict summary

Plan is sound and well-grounded — every referenced path, symbol, line-number claim, and test-seam claim checked out (memberwise inits public, `deleteOne` via GRDB `PersistableRecord`, v2 additive-migration pattern, watermark seeding helper, `makeInMemory()` runs the full migrator so v5 reaches test DBs automatically, `LogClient.testValue` is a safe recorder so new log calls can't break existing tests, `.http.isAlwaysOn` real). The staleness design (single-read equality on two copies of the server clock, D3 stale-serve) has no correctness hole I could break. **8 findings: 1 high (missing Package.swift edits — the plan is unbuildable as written), 2 med, 5 low.** Recommend apply on 1–5, defer 6–8.

## Findings

1. **[HIGH — apply]** The plan mandates `.http` logging from inside `BriefRepositoryLive` and `ProfileRepositoryLive`, but **neither target depends on `LogClient`** (Package.swift ~L456–476 and ~L559–575 — verified absent), and Package.swift appears in no Scope/Files list. `import LogClient` won't build. Precedent is clean (Database and SyncRepositoryLive already take the LogClient INTERFACE for always-on `.http` — the 18.2/19.1 pattern), so it's architecturally sanctioned, just unplanned. Also add `LogClient` to `BriefRepositoryLiveTests`/`ProfileRepositoryLiveTests` so the `LogRecorder` seam is importable. → Change: PLAN.md Scope + TASK-001 Files + TASK-002 Files.

2. **[MED — apply]** `ProfileRecord(domain:)` gaining a `syncServerTime:` parameter breaks an **unlisted call site**: `Sources/Clients/Database/Tests/DomainBodyCacheMigrationTests.swift:39` (`try ProfileRecord(domain: profileDomain).save(db)`). TASK-003 only lists the live file + ProfileCacheTests. Either give the parameter a `nil` default (consistent with the memberwise init's stated `nil` default; "no hidden dependency reads" still holds) or add the file. → Change: TASK-003 Files/Notes.

3. **[MED — apply]** PLAN Risks and RESEARCH misstate current peek behavior: both claim a corrupt row makes the peek's throw land in TodayFeature's error state / "changes hydrate from error to no-cached-brief". In fact **TodayFeature already wraps the peek in `try?`** (`TodayFeature.swift:247`, `TodayOrchestration.swift:75`) — corruption already reads as `nil` at the feature today. The peek change is still right (policy-layer consistency + the log line), but it is *not* a behavior change at the feature, and the "brick" via the peek doesn't exist. → Change: PLAN.md Risks bullet, RESEARCH.md "Error propagation" §.

4. **[LOW/MED — apply]** D3 stale-serve creates an unstated behavior: in the *stale + unreachable-server* state (successful sync, then offline before refetch), **every** `profile()`/`zones()` call attempts the network — including the APIClient retry/backoff window — before serving the cache, plus one `.http` error log per attempt. Window is narrow (device was online seconds earlier for the sync), so accepted-by-design is fine, but the Risks section should say it: latency on the zones chip and log chatter until connectivity returns. → Change: PLAN.md Risks.

5. **[LOW — apply]** Stamp write-window: TASK-003 step 4 says miss/undecodable paths "persist with the **current** watermark stamp" — ambiguous. If implemented by re-reading the watermark at write time, a sync completing mid-`GET /profile` stamps a possibly pre-recompute profile with the *new* `serverTime` → masks the recompute until the next sync. Stamping the pre-fetch value (the step-1 single read, which the REFACTOR step already gestures at) costs at most one redundant refetch and can never mask. Pin it: "stamp the watermark value read before the network fetch; never re-read at write time." → Change: TASK-003 Notes.

6. **[LOW — apply (one-line) or defer]** TASK-003's migration-test hedge ("if the Database test target has the pattern") is resolvable now: the pattern exists — `DomainBodyCacheMigrationTests` does `migrate(queue, upTo:)` → seed → full `migrate()`. State it firmly. Same task also says to update `test_cacheHit_noNetwork` "to a stamped row matching the seeded watermark" — that test seeds **no watermark** (ProfileCacheTests:71–83), so it already IS the case-(e) shape and passes unchanged; the "(or seed no watermark)" branch is the actual current state. → Change: TASK-003 wording.

7. **[LOW — defer]** Epic 19 AC #1 reads "after a constants recompute, `profile()`/`zones()` return the new values" — the design satisfies this only *at the next successful sync* after the recompute (by construction, D1). PLAN's Goal states the cadence honestly; if you want TASK-004's epic-ticking airtight, add one line to the epic AC or PLAN noting "visible at the next sync" as the satisfaction semantics.

8. **[LOW — defer]** Stale docs the diff will brush past: Package.swift's ProfileRepositoryLive comment still says "owns the recompute AsyncStream" (deleted in `b5eed33`); worth fixing in the same PR since finding 1 already edits that block. `ProfileRecord`'s "refreshed when the server recomputes constants" doc becomes true — no change needed.

No defects found in: task ordering (001/002 independent, 003 on 002 — correct, 003 rewrites the same `fetchProfile` 002 touches), D23 preservation (fresh hit stays zero-network), the equality-not-ordering predicate (also correct under watermark regression), GRDB datetime millisecond truncation (both compared values round-trip through the same storage, so truncation is symmetric), `.syncRequired`-on-corrupt-row semantics, or the `hasPriorBrief`-counts-corrupt-row choice (deliberate and documented).

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | BriefRepositoryLive/ProfileRepositoryLive (and their test targets) lack the LogClient dependency the plan's `.http` logging requires; Package.swift unlisted | high | apply | Real unbuildable gap; follow the sanctioned Database/SyncRepositoryLive interface-dep precedent. | PLAN.md:Scope, TASK-001, TASK-002 |
| 2 | `ProfileRecord(domain:)` signature change breaks `DomainBodyCacheMigrationTests:39` | med | apply | Give `syncServerTime:` a `nil` default and note the call site. | TASK-003 |
| 3 | PLAN/RESEARCH misstate the peek path (TodayFeature already `try?`s it — no feature-level brick via the peek) | med | apply | Keep the peek change (consistency + log), correct the claims. | PLAN.md:Risks, RESEARCH.md |
| 4 | Stale+offline: every profile()/zones() call attempts the network (latency + log chatter) until connectivity returns | med/low | apply | Accepted-by-design but must be stated. | PLAN.md:Risks |
| 5 | Stamp must be the pre-fetch watermark value, never re-read at write time (mid-fetch sync would mask a recompute) | low | apply | Pin the non-masking write semantics. | TASK-003 |
| 6 | Migration-test hedge resolvable (pattern exists); `test_cacheHit_noNetwork` already the no-watermark shape | low | apply | Firm up wording. | TASK-003 |
| 7 | Epic AC #1 satisfaction semantics = "visible at the next successful sync" | low | defer | PLAN Goal already states the cadence; noted for TASK-004's epic ticking (annotate the tick with the semantics). | |
| 8 | Stale Package.swift comment ("owns the recompute AsyncStream") in the block finding 1 edits | low | apply | One-line hygiene fold-in. | TASK-002 |
