# Adversarial Review — Round 3

**Run:** 2026-07-10 10:25 UTC
**Branch:** fix/phase-18-2-bounded-hk-reads
**Base:** staging
**Commits reviewed:** 071ae25..5d387c2
**Prior rounds in scope:** reviews/round-1.md, reviews/round-2.md
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging <round-3 focus>`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: both round-2 bound fixes leave the stated cardinality invariant defeatable, and the rejected cancellation race can still dispatch a cancelled sync.

Findings:
- [medium] Activity window returns limit + 1 daily summaries (Sources/Clients/HealthKitClient/Interface/HealthKitClient.swift:42-46)
  The fix converts `now` and a start exactly `limitPerType` days earlier into day-only components. HealthKit's activity predicate is inclusive at both ends, so a one-day limit queries both yesterday and today; in general it can return `limitPerType + 1` summaries. This violates the per-type cap the change claims to enforce, including for the onboarding probe.
  Recommendation: For a positive limit, start at `limitPerType - 1` calendar days before `now` (or otherwise make one endpoint exclusive), and add a regression test for limit 1 plus an assertion that the inclusive date range spans no more than the requested number of days.
- [medium] The bounds initializer still permits an operationally unbounded read (Sources/Clients/HealthKitClient/Interface/HealthKitClient.swift:24-46)
  `max(1, limitPerType)` only excludes HealthKit's zero sentinel. A public caller can pass `Int.max`, which is effectively no row cap for every sample query. It also drives the activity window calculation with an extreme day offset; if that calendar calculation cannot form a date, the explicit fallback returns `since`, reopening a `.distantPast` activity query. Thus the round-2 #3 fix does not make a safe finite bound unrepresentable.
  Recommendation: Enforce a documented finite upper bound (for example, clamp or reject values above the supported maximum/default) and test `Int.max` with `.distantPast` to prove both sample and activity paths remain finitely bounded.
- [medium] Cancellation rejection leaves an uncoordinated POST-dispatch race (Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift:100-106)
  The pre-POST cancellation check is only a snapshot. Cancellation can occur after line 103 and before the arbitrary `apiClient.sync` closure starts; the live transport also has no cancellation check before token work, request construction, or `URLSession.data(for:)`. The rejected rationale is insufficient: server idempotency and withholding the local watermark reduce duplicate-data impact but do not prevent a cancelled, replaced sync from issuing an API request. The existing tests cover cancellation before the check and while a POST is already running, not this gap.
  Recommendation: Add a cancellation-aware dispatch gate with a defined cancellation-vs-dispatch linearization point, check cancellation again in the live transport immediately before request work, and add a deterministic test that cancels in the check-to-closure gap and asserts the sync closure is not entered when cancellation wins.

Next steps:
- Correct the inclusive activity range and cap externally supplied limits.
- Resolve the cancellation-to-dispatch race before relying on cancel-in-flight to prevent overlapping sync requests.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Inclusive day-bucket range spans `limitPerType + 1` days, so the activity window can return one row more than the claimed cap | low (down from med) | fix | Correct: `predicateForActivitySummariesBetweenStart:end:` is inclusive at both day endpoints, so the floor must be `limitPerType - 1` days before now. One-line fix + limit-1 regression test. **NOT acted on — round-3 fix row triggers the escalation stop per the run protocol** | (escalated) |
| 2 | `max(1, ...)` doesn't cap the top: `Int.max` is operationally unbounded, and it can push `activitySince`'s calendar math into the `since` fallback (reopening `.distantPast` for activity) | low (down from med) | defer | Reachable only by a caller deliberately passing an absurd explicit limit — unlike HK's no-limit sentinel (0), `Int.max` is not an idiom a future call site would pass innocently, and every app call site uses `.since(_:)` defaults (single-user app). Worth a follow-up: pick a documented finite ceiling for `limitPerType` and make the `activitySince` fallback conservative (`now`, not `since`) | |
| 3 | Re-push on round-2 #1: cancellation between the pre-POST check and `apiClient.sync` can still dispatch the POST | med | reject | Unchanged grounding, strengthened: the proposed dispatch gate has the identical race one instruction after its linearization point — a cancellation cannot be linearized against a remote side effect that is already on the wire, so no design closes this window. The residual is harmless by the documented idempotent/no-guard decision (D2, characterized by `test_concurrentSync_lastWriterWins_noGuard`) plus the still-blocked watermark write; the live URLSession transport throws promptly on task cancellation, bounding the overlap to instructions | |
