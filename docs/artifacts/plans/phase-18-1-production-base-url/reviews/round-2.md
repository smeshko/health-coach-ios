# Adversarial Review — Round 2

**Run:** 2026-07-10 07:50 UTC
**Branch:** fix/phase-18-1-production-base-url
**Base:** staging
**Commits reviewed:** 4eda7b7..3215d40
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)
**Prior rounds in scope:** reviews/round-1.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: the deferred unconfigured path remains unusable and its only diagnostic is normally suppressed; the loopback guard also has an address-representation bypass.

Findings:
- [high] Unconfigured builds are neither usable in mock mode nor reliably diagnosable (App/CoachApp.swift:34-60)
  The triage defers the Connect failure on the premise that first-launch mock seeding plus this log makes an empty device configuration usable and diagnosable. It does not. A fresh install reaches Connect before any routed repository can select mock; Connect writes the token, calls the injected `.unconfigured` client, then clears the token and shows the generic token-rejected state. Moreover, the new diagnostic is logged as `.app`, while only `.http` is always enabled; default `.app` logging is off, including in Release. Thus the stated fallback cannot complete onboarding and the supposed fail-loud evidence is absent by default.
  Recommendation: Handle an unconfigured-base-URL error separately: provide a configuration path or an onboarding-safe mock bypass, do not clear the token for that error, and emit the configuration diagnostic through an always-on logging path. Add a fresh unconfigured device-style launch test that proves both recovery and diagnostic visibility.
- [medium] Loopback rejection misses equivalent IPv6 representations (Sources/Clients/APIClient/Live/APIBaseURL.swift:53-63)
  `isLoopback` compares host strings and recognizes only `::1` plus IPv4-mapped addresses written with a dotted IPv4 suffix. Equivalent loopback literals such as `https://[::ffff:7f00:1]` (and expanded IPv6 loopback notation) pass the HTTPS/non-loopback guard, despite resolving to loopback. This breaks the plan's explicit invariant that no off-simulator configuration resolves to loopback; the negative tests cover only the dotted mapped spelling.
  Recommendation: Parse and normalize IP literals before classifying them rather than matching textual prefixes, then add expanded IPv6-loopback and hexadecimal IPv4-mapped loopback cases to the resolver test matrix.

Next steps:
- Replace the deferred unconfigured-onboarding behavior with a recoverable configuration/mock path and an always-on diagnostic.
- Harden IP-literal loopback classification and extend resolver tests.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1a | Unconfigured diagnostic logged as `.app`, which is gated off by default (only `.http` is always-on) — the fail-loud log line is invisible unless the dev-menu toggle is flipped, and never emitted in Release | med | fix | Verified: `LogClient.live` gates purely on category (`isAlwaysOn \|\| isLogCategoryEnabled`), `.app` defaults off, and RELEASE hard-resolves every verbose category off. The PLAN decision (validation round-3 #1) leans on this exact line for diagnosability, so it must land on the always-on `.http` category — a base-URL misconfiguration is squarely network-transport observability. | eec3e20 |
| 1b | Unconfigured device DEBUG build still can't complete onboarding (Connect probes the throwing client, clears token) — re-push on round-1 #2's deferral | high | defer | Deferral upheld: PLAN.md Decision (validation round-3 #1) explicitly assigns the Connect probe-failure/token-clearing interplay and any configuration-failure presenter to Phase 18.3; layering an onboarding bypass or don't-clear-token special case into this phase would couple two audit fixes. With 1a fixed, the misconfiguration IS diagnosable from the always-on `.http` log. Tracked as epic Phase 18.3. | |
| 2 | Loopback guard bypassed by equivalent IP representations (`[::ffff:7f00:1]`, expanded `::1`, integer/hex/partial IPv4 literals) | med | fix | Real invariant gap: the plan's acceptance box pins "no build path resolves to localhost — or loopback — off DEBUG+simulator" via resolver tests, and prefix string-matching misses semantically identical literals. Fixed by parsing literals (`inet_aton` for every IPv4 spelling, `inet_pton(AF_INET6)` for every IPv6 form) before classifying; test matrix extended. | 1609881 |
