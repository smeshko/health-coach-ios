# Adversarial Review — Round 2

**Run:** 2026-07-10 10:05 UTC
**Branch:** fix/phase-18-2-bounded-hk-reads
**Base:** staging
**Commits reviewed:** 071ae25..3ff5d5d
**Prior rounds in scope:** reviews/round-1.md
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging <round-2 focus>`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: the round-1 cancellation fix still has an uncoordinated POST-dispatch race, and the claimed bounded-read invariant is bypassable/unmet for two live paths.

Findings:
- [high] Cancellation can still launch a POST after the new pre-POST check (Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift:103-106)
  `Task.checkCancellation()` is only a point-in-time cooperative check. Cancellation can arrive immediately after it returns and before `apiClient.sync(request)` begins. `APIClient.sync` is an arbitrary async closure with no cancellation contract; the live transport also does not check cancellation before beginning token/request work. Thus a cancelled prior sync can still dispatch an irreversible POST (and overlap the replacement sync), despite the new tests only covering cancellation before this check or after the POST has already started.
  Recommendation: Introduce a cancellation-aware dispatch gate with a defined linearization point shared with the cancellation handler, and make the transport reject cancellation before it creates/sends the request. Add a deterministic test that cancels in the check-to-`apiClient.sync` gap and asserts the API closure is never entered.
- [medium] Activity reads remain unbounded for the onboarding distant-past probe (Sources/Clients/HealthKitClient/Live/HKDeltaReads.swift:186-195)
  `readActivity` receives only `since`; `limitPerType` is never applied because `HKActivitySummaryQuery` is constructed without any result cap. The comment calls the date predicate bounded, but onboarding invokes `deltaSamples(.since(.distantPast))`, so this query may materialize every available daily activity summary. The 15-second timeout limits waiting time, not returned-row cardinality, and directly contradicts the plan requirement that every HKQuery be limited.
  Recommendation: Provide a bounded activity strategy, such as querying finite recent date windows with an explicit maximum number of days/windows and stopping once the probe has enough evidence. Add coverage that the distant-past onboarding path cannot request an unbounded activity range.
- [medium] The public bounds type can still express an unbounded HealthKit query (Sources/Clients/HealthKitClient/Interface/HealthKitClient.swift:20-24)
  The public initializer accepts any `Int` without validation, and the live sample queries pass that value directly as `HKSampleQuery.limit`. An iOS caller can supply HealthKit's no-limit sentinel (or an otherwise unsafe value), defeating the stated interface invariant that an unbounded read is not expressible. Current app call sites happen to use the default, but the public API provides no protection against a future caller reopening the original failure mode.
  Recommendation: Validate or make the limit type non-forgeable: require a strictly bounded positive range and reject HealthKit's no-limit sentinel before reaching the live client. Add tests for invalid/no-limit inputs.

Next steps:
- Resolve the POST-dispatch race and add a deterministic regression test.
- Bound activity reads and enforce validated limits before shipping.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Cancellation arriving in the gap between `Task.checkCancellation()` and `apiClient.sync(request)` can still dispatch the POST | med (down from high) | reject | The window is inherent to cooperative cancellation — a "dispatch gate" only moves it (cancel can land one instruction after any gate opens, and a request already on the wire can never be recalled); the residual is harmless by design: `/sync` is idempotent with no local effects (the documented no-guard/last-writer-wins decision in `runSync`, characterized by `test_concurrentSync_lastWriterWins_noGuard`), the pre-write check still blocks the watermark advance, and the live URLSession transport is itself cancellation-aware at its suspension points | |
| 2 | `readActivity` applies no row cap — the onboarding `.distantPast` probe can materialize every daily activity summary | med | fix | Real gap vs the phase Goal ("no HK read can run unbounded"); activity summaries are one-per-day, so clamping the query's start to `limitPerType` days before now enforces the exact same per-type row cardinality as the sample queries, with no semantic change for real data (10 000 days ≈ 27 years > any device HK history) | 5d387c2 |
| 3 | `HealthReadBounds` accepts any `Int`, so `HKObjectQueryNoLimit` (0) or a negative reaches `HKSampleQuery.limit` unvalidated | med | fix | The interface doc explicitly claims "the interface cannot express an unbounded read" — make it true: clamp to `>= 1` and make the fields `let` so the sentinel is unrepresentable post-init | b7a07db |
