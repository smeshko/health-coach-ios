# Adversarial Review — Round 1

**Run:** 2026-07-10 07:42 UTC
**Branch:** fix/phase-18-1-production-base-url
**Base:** staging
**Commits reviewed:** 4eda7b7..3215d40
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: the checked-in Release archive is nonfunctional by default, and the claimed unconfigured DEBUG mock fallback cannot complete onboarding.

Findings:
- [high] A clean Release archive installs a client that fails every API request (CoachApp.xcodeproj/project.pbxproj:342)
  The only checked-in Release value is empty. That expands the plist value to empty; off the DEBUG-simulator path the resolver returns nil, so CoachApp installs APIClient.unconfigured. The archive still builds and signs, but probe/sync/profile/brief requests fail only at runtime. A developer-local Xcode edit is neither reproducible nor enforced, so an unconfigured production archive is easy to ship.
  Recommendation: Provide the Release URL through a controlled archive/CI configuration source and add a Release archive validation that fails when the resolved plist URL is absent or invalid.
- [high] Unconfigured device DEBUG builds cannot actually enter mock mode (App/CoachApp.swift:34-56)
  This seeds mock for an unconfigured first launch, but a fresh install has no token and routes to onboarding. Connect always writes a token then calls apiClient.probe directly; here the injected unconfigured client throws, Connect clears the token, and the user remains on the invalid Connect screen. Mock routing only applies after reaching repository calls, so the advertised usable mock fallback is unreachable on a physical DEBUG device without a base URL.
  Recommendation: Make the unconfigured DEBUG mock path able to bypass or locally satisfy onboarding/probe, or present a configuration flow before Connect; cover a fresh device-style launch through onboarding with no base URL.

Next steps:
- Add an archive-time Release configuration gate.
- Add an end-to-end test for a fresh unconfigured DEBUG device launch.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Clean Release archive resolves `.unconfigured` because `API_BASE_URL` ships empty | high | reject | Contradicts two explicit PLAN.md items: the Decision "`API_BASE_URL` ships empty in the repo" (hostname deliberately kept out of git, RUNBOOK access posture) and Out of Scope "Committing a real hostname — the owner sets `API_BASE_URL` locally in Xcode; the repo ships it empty by design". Fail-loud is the designed guard: the throwing `.unconfigured` client + the composition-root `.app` error log ARE the "archive validation" for a self-hosted single-owner app with no CI/distribution pipeline to gate. The pre-branch behaviour (silent localhost) was strictly worse. | |
| 2 | Unconfigured DEBUG device build can't complete onboarding — Connect probes the throwing client, clears the token, user stuck on Connect | high | defer | Real but explicitly out of this phase's scope by PLAN.md Decision (validation round-3 #1): "a dedicated configuration-failure presenter and the Connect-clears-token interplay are deferred: Phase 18.3 owns exactly that Connect probe-failure/token bug". Also pre-existing in kind: Connect's raw `apiClient.probe()` is not mock-routed on staging either (mock-mode fresh installs already need a reachable backend to pass Connect); this branch changes the failure from silent localhost timeout to a clear thrown config message — diagnosable in the on-device log viewer. Tracked as epic Phase 18.3. | |
