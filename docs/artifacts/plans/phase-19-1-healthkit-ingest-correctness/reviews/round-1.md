# Adversarial Review — Round 1

**Run:** 2026-07-10 15:36 UTC
**Branch:** fix/phase-19-1-healthkit-ingest-correctness
**Base:** staging
**Commits reviewed:** d4d27e6..20ea755
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No ship: existing users are not migrated to the new HealthKit read permissions, and capped replay can still permanently drop late-arriving samples while advancing the watermark.

Findings:
- [high] Existing installs never request the new effort-score permissions (Sources/Clients/HealthKitClient/Live/HKTypeCatalog.swift:47-52)
  This adds two separately-authorized HealthKit read types, but the only authorization request is the onboarding Connect flow; returning token-holding users go straight to the main app. Their relationship queries therefore return no effort samples, which is intentionally converted to nil and synced; after the 48-hour replay window expires, those workouts are not revisited. The advertised effort fix consequently fails permanently for upgraded users unless they re-enter onboarding.
  Recommendation: Add a versioned authorization reconciliation path for existing users that calls requestAuthorization with the expanded read set (and surfaces a recoverable Settings prompt when declined) before relying on effort ingestion.
- [high] Truncation is detected but still commits an unrecoverable watermark (Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift:186-193)
  When a type reaches the query limit, the code only emits a log and continues the sync. Because samples are fetched newest-first, the omitted oldest records can include late arrivals; the successful POST then advances the anchor, so a later 48-hour replay no longer includes them. This is permanent silent data loss in normal production operation, with observability but no recovery.
  Recommendation: Do not advance the watermark for a truncated type, or replace the capped start-date replay with pagination/partitioned windows or HK anchored queries so every eligible sample is drained before committing progress.

Next steps:
- Implement an authorization-upgrade path and test it with a previously onboarded user.
- Make capped reads recovery-safe before allowing the watermark to advance.

## Triage

<!--
Verdict values:
  fix    — real bug; address now in this branch
  defer  — has merit but out of scope; capture as a follow-up
  reject — contradicts an explicit Decision in PLAN.md, or is taste/speculation

One row per finding. Number them so subsequent rounds can reference them
(e.g. "round-1 #3 is unaddressed"). Severity is one of: high, med, low.
Commit is the fix SHA when verdict is `fix`; empty otherwise.
-->

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Existing installs never request the new effort-score read permissions (only auth entry point is onboarding; session restore skips it) | med | defer | Factually correct, but the affected population is empty for this app: it is single-user and the sole production device has not been onboarded yet (Epic 18 owner device validation still pending), so the first real onboarding will request the full read set including the effort types; DEBUG installs re-onboard trivially via the dev-menu reset-token path. A versioned auth-reconciliation on session restore is the right durable pattern for any *future* read-set expansion and is filed as a follow-up — it touches AppFeature (which has no HealthKitClient dependency today), well outside this phase's scope. | |
| 2 | Truncation is detected but the watermark still advances — capped replay can permanently drop old rows | high | reject | Contradicts explicit Decision D1 (DECISIONS.md), which already weighed exactly this and was re-litigated in validation round-2 #1: in-scope mitigation is *visibility* (the `.http` truncation warning this branch ships), prevention is the documented anchored-query follow-up with an explicit trigger (warning firing on device). The pathological case needs >10k samples of one type inside 48h (~3.5/min continuously) — only continuous HR approaches it, and its marginal effect is load-aggregate precision, not the readiness/safety inputs this phase repairs. The proposed "don't advance the watermark for a truncated type" alternative is worse: the window never shrinks, so a persistently chatty type livelocks the sync into re-reading/re-sending 10k rows forever. | |
