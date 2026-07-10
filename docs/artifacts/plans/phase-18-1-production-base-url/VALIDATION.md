# Validation Summary — phase-18-1-production-base-url

**Rounds:** 3
**Plan status at validation:** draft
**Run on:** 2026-07-10

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 3        | 3       | 0        | 0        |
| 2     | 3        | 2       | 0        | 1        |
| 3     | 4        | 4 (one slim) | 1 (presenter arm of #1) | 0 |

## Applied

### Round 1
- TASK-001:Files, TASK-004:Files, PLAN.md:Risks, RESEARCH.md — resolver API made `public`;
  pbxproj needs 4 file-registration records for `AppConfig.swift` (verified: no synchronized
  groups) (round-1 #1)
- TASK-001, PLAN.md:Scope/Decisions/Acceptance — HTTPS-only off the DEBUG+simulator path;
  cleartext http confined to the insecure fallback (round-1 #2)
- TASK-004:Acceptance/Notes, TASK-005:Steps, PLAN.md:Decisions/Acceptance — simulator runtime
  demonstration (`.http` log showing configured host) added as a mandatory land gate
  (round-1 #3, partial — see Deferred/Rejected)

### Round 2
- TASK-005:Steps — final-validation checklist made consistent with the CI-pending device
  criterion: it is explicitly carved out, epic boxes this phase can't demonstrate stay
  unticked with a pending note (round-2 #2)
- TASK-001:Files/Acceptance — https loopback rejected off the fallback path (round-2 #3)

### Round 3
- TASK-004:Files, PLAN.md:Decisions — composition-root `.app` log line when the unconfigured
  arm is taken (slim arm of round-3 #1)
- TASK-001:Files/Acceptance — loopback classification (127/8, `localhost.` trailing dot,
  IPv4-mapped IPv6) + extended negative test matrix (round-3 #2)
- TASK-004:Acceptance — explicit `-configuration Release` override build + Release-product
  Info.plist inspection (round-3 #3)
- TASK-004:Files — `import Foundation` in AppConfig.swift (round-3 #4)

## Deferred

- (round-3 #1, presenter arm) Typed configuration-failure signal + onboarding/error
  presentation + "unconfigured must not clear a valid token" — Phase 18.3 owns the Connect
  probe-failure/token-clearing bug this interacts with; folding a presenter change into 18.1
  would couple two audit fixes. The slim log-line arm landed here; carry the presenter check
  into Phase 18.3's plan.

## Rejected

- (round-2 #1) Make the physical-device probe/sync a phase-completion blocker — contradicts
  the explicit PLAN.md Decision: the autonomous pipeline cannot operate the owner's phone or
  self-hosted server; the workflow's CI-pending mechanism exists for this. The gap is recorded
  honestly (PR body + unticked epic acceptance box + owner-pending note), so the phase is not
  misreported as device-demonstrated. Round-3 was explicitly told this and did not re-raise.

**Note:** round 3 produced applies, which per protocol normally stops for the user; this run
was user-ordered autonomous ("no interview, best judgement"). All round-3 findings were
refinement-grade (imports, build configuration, alias matrix, one log line) — applied and
concluded without a fourth round.
