# Adversarial Review — Round 2

**Run:** 2026-07-10 12:20 UTC
**Branch:** fix/phase-18-3-probe-connect-hardening
**Base:** staging
**Commits reviewed:** 9c189c8..91f1ec4
**Prior rounds in scope:** reviews/round-1.md
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging` + round-1 triage focus)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No ship: the rejected error-classification finding remains valid, and the new probe bounds falsely report dormant-but-authorized Health data as not shared.

Findings:
- [medium] Confirmed server failures are still shown as connectivity failures (Sources/Features/OnboardingFeature/Sources/ConnectComponent.swift:132-146)
  The reducer maps every non-401 error to `.unreachable`. This includes `APIError.decoding` after a 2xx response and envelope/unexpected-status errors after an HTTP response, so the new UI claims the server could not be reached even when it did respond. The round-1 rejection only explains wrong-base-URL cases; it does not cover a backend/schema regression or an actual server-side error. Users are told to check their connection, while the candidate is cleared and the actionable failure is hidden behind a retry loop.
  Recommendation: Classify only transport/unconfigured failures as `.unreachable`; render confirmed HTTP/decode failures with neutral or server-error copy. Add coverage for `.decoding`, `.envelope`, and `.unexpectedStatus`.
- [medium] A one-year activity window is treated as a permission check (Sources/Clients/HealthKitClient/Interface/HealthKitClient.swift:42-43)
  The new factory sets `limitPerType` to 365. The live activity query derives its start date from this value, so this turns the prior roughly 10,000-day presence window into 365 days. A user whose legitimately shared activity/ring data is older than a year will return an empty activity slice and be marked missing; the degraded screen labels that row “Not shared.” This is a false permission diagnosis introduced by the dedicated bounds, not merely a degraded timeout.
  Recommendation: Decouple activity-presence lookback from the sample-row limit, or retain the prior bounded long activity window for this probe. Add a regression test that activity data older than 365 days does not produce a `Not shared` result.

Next steps:
- Address both classification errors and add the boundary tests before shipping.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | (re-push of round-1 #1) Server-replied non-401 errors (`.decoding`, `.envelope`, `.unexpectedStatus`) still render as "Can't reach the server" | med | reject | Round-1 rejection upheld — PLAN.md Scope explicitly decides "ANY other error → `.unreachable`" and AC-2 pins `.decoding` → `.unreachable` as a tested arm. The backend/schema-regression case Codex adds does not change the calculus: in both arms the candidate clearing, the retry affordance (re-tap), and the remedy surface (the server) are identical — a third `Validation` state changes copy only. The D19 "no raw error strings" rule forbids surfacing the thrown message, the always-on `.http` log carries the precise cause (18.1 diagnostic), and this is a single-owner self-hosted deployment: the person reading the copy operates the server. | |
| 2 | `presenceProbe` `limitPerType: 365` shrinks the activity presence window to 1 year — >1-year-dormant activity reads "Not shared" | med | reject | Contradicts an explicit PLAN.md Decision that names exactly this trade-off: "365 keeps 'old-but-granted reads present' true for a year of inactivity while staying firmly bounded." The prior ~10,000-day window was 18.2's incidental sync default, not designed probe semantics. HK read-presence is inherently heuristic (Apple masks read grants — the status map is only "a corroborating hint" per DECISIONS #2), and the residual — a user onboarding a training app whose newest activity ring is >1 year old — lands on a non-blocking informational screen ("Not shared" pill + "Open Health settings" + Continue), not a hard block. Decoupling the activity window from `limitPerType` reopens the 18.2 review #2.2 dual-purpose design, out of scope per PLAN Out-of-Scope ("any change to the 18.2 read internals"). | |
