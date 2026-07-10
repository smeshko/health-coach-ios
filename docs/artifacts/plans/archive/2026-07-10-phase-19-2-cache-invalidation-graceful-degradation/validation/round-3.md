# Adversarial Validation — Round 3

**Run:** 2026-07-10
**Reviewer:** subagent (general-purpose — Codex usage-capped)
**Plan:** phase-19-2-cache-invalidation-graceful-degradation
**Status at start:** draft
**Prior rounds in scope:** validation/round-1.md, validation/round-2.md

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

## Verdict summary

Third pass complete — all five round-2 applies are in place, correctly worded, and grounded. The two things the prompt flagged for re-verification both check out against the codebase:

- **Raw-SQL seed instruction (TASK-003) is correct.** The pre-v5 `profile` table is created in `v1_createCachedEntities` with exactly `(id, constitutionVersion, body)` (`Sources/Clients/Database/Sources/Migrations.swift:50–54`) and no migration v2–v4 touches it, so a raw insert "pinned to the pre-v5 schema" at the test's `migrate(upTo: "v2_…")` point is well-defined. The body-bytes recipe is valid public API: `ProfileRecord.init(domain:)` is `public` and throwing, `.body` is `public` (`ProfileRecord.swift:13,22`), and `DomainBodyCoder` is indeed internal (`enum DomainBodyCoder`, no access modifier) — so the "via `try ProfileRecord(domain: profileDomain).body`" route is the right one.
- **LogRecorder API names are real.** `LogRecorder` (with `record(_:)`/`entries`), `LogClient.recording(into:)`, the safe bare `testValue` recorder, and the `\.log` dependency key all exist exactly as TASK-001 cites them, in `Sources/Clients/LogClient/Interface/LogClient+TestValue.swift` / `LogClient.swift`. Both stale Package.swift comments TASK-002 names exist at lines 542 and 557; the epic AC-#1 wording TASK-004 quotes matches `docs/artifacts/epics/19-trustworthy-numbers.md:107`, and the 19.1 italic-annotation precedent is real (lines 67–78).

I also re-checked the seams the applies lean on: `@Dependency` is already the in-function pattern in `DailyBriefPolicy.swift` and `ProfileRepository+Live.swift` (so the `.http` log call slots in), both test suites route through `withDependencies` helpers, the migration test's other seeds are raw SQL as claimed, and after full migration the retained profile row still decodes (v5's nullable column reads as `nil` into `Date?`). Nothing in the round-2 edits would bite during implementation. Two residual observations, both below the bite threshold:

## Findings

1. **[LOW — defer (or one-line fold-in)]** A third stale recompute comment survives the #8/#4 hygiene sweep: `Package.swift:923` — "ProfileRepository.live cache/**refresh/recompute** tests" on the `ProfileRepositoryLiveTests` block, the exact block TASK-002 edits to add `LogClient`. Rationale for defer: unlike the 542/557 comments, this one becomes approximately true again once TASK-003 lands (the suite will genuinely cover refetch-on-recompute), so it self-heals; fold it in only if the implementer is already rewording that block.

2. **[LOW — reject / no action]** TASK-001's acceptance says to inject "`$0.log = .recording(into:)` in the existing `withDependencies` setup", but neither suite has a per-test `$0` closure — the setup lives inside shared fixed-parameter helpers (`runWithSofia` in `BriefTestSupport.swift:51–65`, `ProfileCacheTests.run` at lines 34–45). The implementer will trivially add an optional `log:` parameter (defaulting to `.testValue`, so untouched tests can't break — the same property the task already cites). The phrasing is slightly imprecise but cannot mislead anyone into a wrong implementation.

No further action needed: the plan is implementation-ready as written. Neither finding warrants a fourth round.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Third stale recompute comment (Package.swift:923, ProfileRepositoryLiveTests block) | low | defer | Self-heals once TASK-003 lands (the suite will genuinely cover refetch-on-recompute); fold in only if already rewording that block. | |
| 2 | TASK-001's `$0.log` injection phrasing vs the suites' fixed-parameter helpers | low | reject | Phrasing imprecision that cannot mislead — the task already cites the safe-default property the trivial adaptation relies on. | |
