# Adversarial Validation — Round 2

**Run:** 2026-07-10
**Plan:** phase-18-1-production-base-url
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)
**Prior rounds in scope:** validation/round-1.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the revised plan still permits phase completion without proving the device-facing goal, and its final-validation steps conflict with the deliberately deferred criterion.

Findings:
- [high] The deferred physical-device proof is still a required acceptance, not a CI-pending optional (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-004-composition-root-wiring-appconfig-info-plist-key-api-base-url-build-setting-explicit-apiclient.md:42-46)
  The plan substitutes a simulator request whose TLS/DNS failure is explicitly acceptable for the required real-backend device validation. That only proves the configured string reached the client; it cannot establish that a release/device build can connect through the real ingress and complete probe/sync. The defer rationale therefore leaves the phase's primary failure mode untested.
  Recommendation: Make a physical-device probe and sync against the configured HTTPS backend a release/phase-completion gate. If unavailable, leave the phase blocked rather than treating it as production-ready.
- [high] Final validation cannot both leave device acceptance unticked and complete the phase (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-005-final-validation.md:8-27)
  TASK-005 requires all PLAN acceptance criteria to be met, while PLAN intentionally retains the physical-device criterion as CI-pending and unticked. The same task then directs the implementer to tick the phase acceptance criteria and mark the phase done. This creates an impossible validation state that pressures a false epic completion or an ignored checklist item.
  Recommendation: Split implementation validation from phase completion: do not permit the epic update or done status until the device criterion has evidence, and explicitly mark TASK-005 blocked when that evidence is absent.
- [medium] The resolver contract still allows HTTPS loopback off the simulator path (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-001-apibaseurl-resolver-in-apiclientlive-with-simulator-fallback-tests.md:15-39)
  The proposed resolver accepts any URL with a host and an HTTPS scheme when insecure fallback is disabled. That includes https://localhost, https://127.0.0.1, and IPv6 loopback, yet the acceptance text requires that no localhost URL resolve off DEBUG+simulator. The specified algorithm and required test cannot both hold; a release setting can therefore still point the bearer-token client at device loopback or the implementation must silently add undeclared behavior.
  Recommendation: Explicitly reject localhost and IPv4/IPv6 loopback hosts whenever allowInsecureFallback is false, and add a table-driven test matrix for those HTTPS forms.

Next steps:
- Restore physical-device probe and sync as a phase-completion gate.
- Make TASK-005's completion and epic-update instructions consistent with that gate.
- Amend resolver validation to reject loopback HTTPS off DEBUG+simulator.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Physical-device proof should block phase completion | high | reject | Contradicts the explicit PLAN.md Decision ("Sim-runtime demonstration is the land gate; physical-device probe is owner CI-pending"): the pipeline has no access to the owner's phone/server, the run is autonomous by user order, and the workflow's CI-pending mechanism (final-validation template + implement-plan) exists for exactly this. The gap is honestly recorded: PR body + unticked epic box, so nothing is misreported as demonstrated | |
| 2 | TASK-005 internally inconsistent: "all criteria met" vs deliberately-unticked CI-pending criterion | high | apply | Real defect the round-1 edit introduced — the checklist must carve out the CI-pending criterion and pin exactly which epic boxes may be ticked | TASK-005:Steps |
| 3 | Resolver accepts https loopback off the fallback path | med | apply | Correct — reject loopback hosts (localhost/127.0.0.1/::1) whenever the insecure fallback is off; table-driven tests | TASK-001:Files/Acceptance |
