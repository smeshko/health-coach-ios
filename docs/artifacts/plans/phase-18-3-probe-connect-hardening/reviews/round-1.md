# Adversarial Review — Round 1

**Run:** 2026-07-10 12:09 UTC
**Branch:** fix/phase-18-3-probe-connect-hardening
**Base:** staging
**Commits reviewed:** 9c189c8..91f1ec4
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No ship: the new non-401 path mislabels server responses as connectivity failures.

Findings:
- [medium] Server-replied failures are rendered as “Can't reach the server” (Sources/Features/OnboardingFeature/Sources/ConnectComponent.swift:132-146)
  The reducer maps every error other than `APIError.unauthorized` to `.unreachable`. That includes `APIError.decoding`, which the transport produces after receiving a 2xx response whose body cannot decode, plus envelope/unexpected-status errors produced after receiving non-401 HTTP responses. In those cases the server was reached, but the UI tells the user to check their connection/server address, hiding a server/protocol failure behind a false diagnosis.
  Recommendation: Classify only transport-level failures (including timeout and unconfigured-client errors) as `.unreachable`. Add a separate server-response failure state with accurate copy, or use a neutral retryable error, and test 2xx-decode and non-401 HTTP error cases.

Next steps:
- Split non-401 API errors by transport versus confirmed HTTP response before shipping.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Non-401 server-replied errors (`.decoding`, `.envelope`, `.unexpectedStatus`) render as "Can't reach the server" | med | reject | Contradicts the plan's explicit design: PLAN.md Scope decides "ANY other error → `.unreachable`" and AC-2 explicitly pins `.decoding` → `.unreachable` (tested `[transport, decoding]`); Decisions fix the copy at the D19 boundary ("no raw error strings"). The 401-vs-rest axis is the phase's point — only a 401 is a token VERDICT; everything else must not read as token rejection. The copy "check your connection and server address" is deliberately broad and is precisely the actionable remedy for the realistic server-responded non-401 failures in this single-owner app (wrong base URL hitting some other server → 404/HTML → `.unexpectedStatus`/`.decoding`); Codex's proposed transport-vs-response split would mislabel exactly those as "server error" when the fix is the address. The `.http` log carries the precise cause (18.1 always-on diagnostic). A third `Validation` state + copy + snapshot pair is scope expansion with no behavioural gain: candidate clearing and retry (re-tap) are identical in both arms. | |
