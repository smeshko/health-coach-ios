# Adversarial Review — Round 2

**Run:** 2026-07-10 15:55 UTC
**Branch:** fix/phase-19-1-healthkit-ingest-correctness
**Base:** staging
**Commits reviewed:** d4d27e6..20ea755
**Prior rounds in scope:** reviews/round-1.md
**Reviewer:** subagent (self, fresh adversarial pass — Codex usage-limited until 19:10; per the shared-protocol fallback)

## Reviewer output

<!-- Codex was unavailable (usage limit). This round was run as a clean adversarial pass over the
full branch diff with the round-1 file as context, per adversarial-rounds.md fallback. -->

Second pass over the branch diff (`d4d27e6..20ea755`), with round-1's triage under challenge.

**Round-1 triage verification:**

- Round-1 #1 (existing installs never re-request the new effort read permissions) — **defer stands**.
  Verified: the only `healthKitClient.requestAuthorization()` call site in the app is
  `OnboardingFeature/HealthKitPriming.swift`; `AppFeature` has zero HealthKitClient dependency and
  its session restore goes straight to `.main`. So the finding is factually right in general. But the
  affected population is genuinely empty for this app: single user, the sole production device has
  not completed onboarding yet (Epic 18 owner device validation still pending), so the first real
  onboarding will run with the expanded read set; DEBUG installs re-onboard via the dev-menu
  reset-token path. The deferred auth-reconciliation follow-up is the right durable pattern for
  future read-set expansions.
- Round-1 #2 (truncation still advances the watermark) — **reject stands**. D1 in DECISIONS.md
  explicitly weighs prevention vs visibility and was re-litigated in plan-validation round-2 #1;
  visibility (the `.http` warning this branch ships) is the in-scope mitigation, anchored queries
  the documented follow-up with an explicit trigger. Codex's "don't advance the watermark for a
  truncated type" alternative was checked and is worse: the window never shrinks for a persistently
  chatty type, so every subsequent sync re-reads/re-sends the full 10k cap forever — a livelock in
  the exact case the finding worries about.

**New findings from this pass:**

1. [low] Workouts already ingested by earlier builds carry numeric `type` strings on the backend
   (`"37"` etc.); the fix corrects the wire form going forward and, via the 48h lookback re-send,
   the last two days — but older rows are not repaired, so any backend classification over that
   history stays wrong until it ages out.

**Checked and found sound (no findings):**

- `QueryLifecycle.finishStoppingHandle` race analysis: resume-before-stop leaves phase `.finished`
  under the lock first, so a concurrent `cancel()` no-ops (never a double `stop()`); post-delivery
  and post-cancellation deliveries are dropped; `.idle` delivery parks the result and a later
  `register` returns `.alreadyCancelled` so the handle is never executed.
- `ChildQueryRegistry` add/cancel race: either the cancel sweep's snapshot contains the child, or
  `add` observes `cancelled == true` and cancels it on the spot — no escape window. `stoppedHandleCount`
  sums children exactly and excludes normally-completed ones.
- Effort read degrades honestly: an error/denied/empty relationship delivery reduces over `[]` → nil
  effort, never a thrown error for the whole read; task/timeout cancellation reaches the dynamic
  children through the registry seated in the coordinator's fixed array.
- `deltaReadSince` clamps at `backfillFloor` including the nil-anchor first-sync case; the watermark
  still persists the raw `readInstant` (lookback applied at read time only — no migration).
- `truncatedTypes` buckets are 1:1 with `recordQuerySpecs` (verified: one HK type per `RecordType`),
  so the warning cannot under-report; workouts/activity summaries counted as their own buckets.
- `#available(macOS 15.0, *)` guards evaluate true on any iOS runtime (the `*` clause), so the
  effort types are always in the read set on device; the guard exists only for the macOS 14 host floor.
- Package.resolved churn is benign hygiene: it drops stale `swift-log`/`swift-tagged` pins that no
  longer exist anywhere in `Package.swift` (on staging or this branch).
- Test coverage matches the acceptance criteria: lookback + floor-clamp bounds capture, truncation
  pure seam + end-to-end `.http` warning, activity-name pins + full known-rawValue sweep
  (never-numeric, always-snake-case), distance candidates end-to-end, effort preference seam,
  dynamic-child lifecycle exact-count contracts.

Verdict: no fix rows. Round-1 triage upheld; one new low-severity finding, rejected below.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Backend workout rows ingested by earlier builds keep numeric `type` strings; only rows re-sent within the 48h lookback get repaired | low | reject | No production ingest has ever run — the iOS client has only synced dev/sim data (owner device validation is still pending), and the backend's pre-iOS data is already in canonical name form. There is no real polluted history to repair, and backend changes are explicitly Out of Scope in PLAN.md. | |
