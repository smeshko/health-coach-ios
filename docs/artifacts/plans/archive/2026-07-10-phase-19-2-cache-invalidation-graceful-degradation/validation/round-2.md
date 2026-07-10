# Adversarial Validation — Round 2

**Run:** 2026-07-10
**Reviewer:** subagent (general-purpose, continued round-1 reviewer lineage — Codex usage-capped)
**Plan:** phase-19-2-cache-invalidation-graceful-degradation
**Status at start:** draft
**Prior rounds in scope:** validation/round-1.md

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

## Verdict summary

All eight round-1 edits are present, correctly placed, and faithful to the triage (PLAN Scope/Risks, RESEARCH error-propagation §, TASK-001/002 Files, TASK-003 Files/wording/Notes all check out; the Package.swift additions follow the sanctioned Database/SyncRepositoryLive interface-dep precedent and collide with no layering rule). **But the #2 fix is insufficient: the `nil` default keeps `DomainBodyCacheMigrationTests:39` *compiling* and then breaks it at *runtime* — verified in GRDB source.** 5 findings: 1 high (new, introduced by the edit's reasoning), 1 med, 3 low. Recommend apply on #1–#4; #5 is a mild pushback on the #7 defer.

## Findings

1. **[HIGH — apply]** The round-1 #2 fix doesn't actually save `DomainBodyCacheMigrationTests`. GRDB **overrides `encodeIfPresent`** so nil optionals are persisted as NULL — the key still enters the persistence container (`EncodableRecord+Encodable.swift`: generic `encodeIfPresent` does `persist(nil, forKey:)` on nil), and `insertStatement` builds `insertedColumns: persistenceContainer.columns` with **no table-column filtering** (`MutablePersistableRecord+DAO.swift:31–34`). The test migrates only `upTo: "v2_…"` (pre-v5 `profile` table, no `syncServerTime` column) and then `ProfileRecord(domain:).save(db)` → INSERT includes `syncServerTime` → SQLite "table profile has no column named syncServerTime". TASK-003's claim "must keep compiling unchanged" is true but the test **fails at runtime** regardless of the default. → Change TASK-003: add `Sources/Clients/Database/Tests/DomainBodyCacheMigrationTests.swift` to Files and convert the line-39 seed to a raw-SQL insert (schema-pinned, like every other seed in that test; body via `try ProfileRecord(domain: profileDomain).body` since `DomainBodyCoder` is internal). Keep the `nil` default anyway — it's still right for the other call sites (`ProfileCacheTests.seedProfile` runs on a fully-migrated DB and is fine).

2. **[MED — apply]** The #1 edit makes TASK-001's log-assertion hedge stale and self-contradictory. TASK-001 acceptance still says "assert via the LogClient test seam **if one exists** … otherwise the log call's presence is covered by code review" — but the applied Package.swift edit *guarantees* the seam (LogClient in both test targets; `LogRecorder` + `.recording(into:)` live in the interface at `LogClient+TestValue.swift`; both suites already inject via `withDependencies` — `ProfileCacheTests.run` and `BriefTestSupport.runWithSofia` — so adding `$0.log = .recording(into:)` is one line, and the bare `testValue` recorder default means untouched tests can't break). Meanwhile PLAN AC #5 ("every decode-degradation event logs on `.http`") + TASK-004's "no criterion ticked on 'the code looks right'" forbid the code-review escape hatch. → Change TASK-001 acceptance: drop the hedge, require the recorder assertion.

3. **[LOW — apply]** Residual ambiguity the #5 fix was meant to kill: TASK-003 Files step 4 still says miss/undecodable paths "persist with the **current** watermark stamp too" — "current" is the exact word round-1 #5 flagged. The Notes pin the pre-fetch semantics, but step 4 contradicts them on a lazy read. → One-word change: "the step-1 (pre-fetch) watermark value".

4. **[LOW — apply]** The #8 stale-comment fix covers only the Live block. The ProfileRepository **interface** block comment two targets up (Package.swift:542) is equally stale: "cache-first profile fetch + zone-range accessor + **recompute stream**". TASK-002's fold-in edits the adjacent Live block anyway. → Extend TASK-002's #8 bullet to both comments.

5. **[LOW — pushback on the #7 defer, one-line apply]** I agree the epic AC itself shouldn't be reworded here, but the triage's own mitigation ("annotate the tick with the semantics") lives **only in round-1.md**, which implement-plan never reads — TASK-004's epic-update steps are generic. Epic 19's already-ticked 19.1 criteria carry exactly this kind of italic annotation, so the precedent exists. → Add one bullet to TASK-004's Epic update section: "annotate the AC-#1 tick with 'new values visible at the next successful sync' (validation round-1 #7)". If you'd rather keep TASK-004 template-pure, the defer stands but accept that the annotation will likely be lost.

**Confirmed clean (no action):** Package.swift layering (repos already take client interfaces; LogClient precedent in Database/APIClient/SyncRepositoryLive blocks), test-target names/paths, `v5_addProfileSyncServerTime` naming consistency across PLAN/TASK-003, `.datetime`-truncation symmetry, `test_cacheHit_noNetwork` = case (e) exactly as now worded (ProfileCacheTests:71–83, no watermark seeded), the #3 peek correction (matches `TodayFeature`'s `try?`), the #4 stale+offline risk bullet, and the D2/D3 failure-ordering coverage in TASK-002/003 acceptance.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | nil default saves compilation but the pre-v5-schema migration test still breaks at runtime (GRDB persists nil optionals — INSERT names the missing column) | high | apply | Grounded in GRDB source; convert the seed to a raw-SQL pre-v5 insert; keep the nil default for migrated-DB call sites. | TASK-003 |
| 2 | TASK-001's log-assert hedge now self-contradictory (the seam is guaranteed by the same plan) | med | apply | Require the `LogRecorder` assertion; no code-review escape hatch. | TASK-001 |
| 3 | "current watermark stamp" wording still contradicts the pre-fetch Notes pin | low | apply | One-word fix in step 4. | TASK-003 |
| 4 | Second stale recompute comment (interface block, Package.swift:542) | low | apply | Fold into the same hygiene bullet. | TASK-002 |
| 5 | Round-1 #7 defer's mitigation lived only in round-1.md (implement-plan never reads it) | low | apply | Added the tick-annotation bullet to TASK-004's epic-update steps. | TASK-004 |
