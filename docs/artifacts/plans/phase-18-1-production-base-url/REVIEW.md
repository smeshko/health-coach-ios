# Review Summary — phase-18-1-production-base-url

**Rounds:** 3
**Fix commits:** 1609881..eec3e20

## Rounds

| Round | Findings | Fixed | Deferred | Rejected |
|-------|----------|-------|----------|----------|
| 1     | 2        | 0     | 1        | 1        |
| 2     | 3 (one split into 1a/1b) | 2 | 1 (re-push, upheld) | 0 |
| 3     | 0 (approve) | 0  | 0        | 0        |

## Fixes

### Round 2
- `1609881` — parse IP literals in the loopback guard instead of string-matching: hex-half
  IPv4-mapped (`[::ffff:7f00:1]`), expanded IPv6 loopback, and integer/hex/partial IPv4
  spellings previously bypassed the off-simulator https guard; classification now goes through
  `inet_aton` / `inet_pton(AF_INET6)` (zone index stripped) and the resolver test matrix pins
  the equivalent representations (round-2 #2)
- `eec3e20` — emit the composition-root unconfigured-URL diagnostic on the always-on `.http`
  log category: `.app` is gated off by default (and unconditionally off in RELEASE), so the
  fail-loud line was invisible exactly when needed (round-2 #1a)

## Deferred

- (round-1 #2, re-pushed as round-2 #1b) Unconfigured DEBUG **device** build cannot complete
  onboarding: Connect writes the token, probes the throwing `.unconfigured` client, clears the
  token, and shows the generic token-rejected state — the seeded mock mode is only reachable
  past onboarding. Deferral grounded in the PLAN.md Decision (validation round-3 #1): the
  Connect probe-failure/token-clearing interplay and any configuration-failure presenter are
  exactly Phase 18.3's scope; coupling the two audit fixes here was explicitly decided against.
  Also pre-existing in kind — Connect's raw `apiClient.probe()` was never mock-routed; with
  `eec3e20` the misconfiguration is now diagnosable from the always-on `.http` log. Tracked as
  epic Phase 18.3 (Linear not wired for this plan — `Linear: none`).

## Rejected

- (round-1 #1) "A clean Release archive installs a client that fails every API request; add a
  CI/archive configuration gate." Contradicts two explicit PLAN.md items: the Decision
  "`API_BASE_URL` ships empty in the repo" (self-hosted, hostname deliberately kept out of git)
  and Out of Scope "Committing a real hostname — the owner sets `API_BASE_URL` locally in
  Xcode". This is a single-owner personal app with no CI/distribution pipeline to gate; the
  designed guard is fail-loud (throwing `.unconfigured` client + always-on `.http` error log)
  instead of the pre-branch silent-localhost behaviour.
