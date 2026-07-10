# Review Summary — phase-19-1-healthkit-ingest-correctness

**Rounds:** 2
**Fix commits:** none — no fix rows in either round

## Rounds

| Round | Findings | Fixed | Deferred | Rejected |
|-------|----------|-------|----------|----------|
| 1 (Codex) | 2 | 0 | 1 | 1 |
| 2 (subagent self-pass — Codex usage-limited) | 1 | 0 | 0 | 1 |

## Fixes

None. Both rounds produced only defer/reject rows; the branch is unchanged from its
task commits (`56717cb..20ea755`).

## Deferred

<!-- Findings worth doing later but out of scope here. Each becomes a follow-up suggestion in the PR body. -->

- (round-1 #1) Existing installs never re-request the new effort-score read permissions — the only
  `requestAuthorization` call site is the onboarding Connect flow, and session restore skips it, so
  an already-onboarded install would sync `effortScore: nil` forever. Deferred because the affected
  population is empty for this app: single user, and the sole production device has not completed
  onboarding yet (Epic 18 owner device validation pending), so the first real onboarding requests
  the full read set; DEBUG installs re-onboard via the dev-menu reset-token path. Follow-up: a
  versioned authorization-reconciliation on session restore (AppFeature currently has no
  HealthKitClient dependency), to be picked up before any future read-set expansion ships to an
  already-onboarded device. *(Linear not wired — no issue filed.)*

## Rejected

<!-- Findings we pushed back on. Surfaces what Codex flagged and why we said no, so PR reviewers see the reasoning. -->

- (round-1 #2) Truncation is detected but the watermark still advances — capped replay can
  permanently drop old rows. Contradicts explicit Decision D1 (DECISIONS.md), already re-litigated
  in plan-validation round-2 #1: the in-scope mitigation is *visibility* (the always-on `.http`
  truncation warning this branch ships); prevention is the documented anchored-query follow-up whose
  trigger is that warning firing on device. The pathological case needs >10k samples of one type
  inside 48h (~3.5/min continuously) — only continuous HR approaches it, and its marginal effect is
  load-aggregate precision, not the readiness/safety inputs this phase repairs. Codex's
  "don't advance the watermark for a truncated type" alternative livelocks: the window never
  shrinks, so every later sync re-reads/re-sends the full 10k cap forever.
- (round-2 #1) Backend workout rows ingested by earlier builds keep numeric `type` strings and are
  not repaired beyond the 48h lookback re-send. No production ingest has ever run (iOS has only
  synced dev/sim data; owner device validation pending) and the backend's pre-iOS data is already in
  canonical name form — there is no real polluted history — and backend changes are explicitly Out
  of Scope in PLAN.md.
