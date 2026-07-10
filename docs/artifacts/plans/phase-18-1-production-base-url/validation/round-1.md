# Adversarial Validation — Round 1

**Run:** 2026-07-10
**Plan:** phase-18-1-production-base-url
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan leaves the app-target change non-buildable as specified, permits an insecure/unusable production URL, and defers the only validation that proves the device-facing goal.

Findings:
- [high] AppConfig wiring cannot compile from the listed edits (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-004-composition-root-wiring-appconfig-info-plist-key-api-base-url-build-setting-explicit-apiclient.md:13-25)
  TASK-004 says the pbxproj change is only one build-setting line per configuration and calls the work “four edits.” The current project uses ordinary PBXGroup/PBXFileReference/PBXSourcesBuildPhase entries; it does not use a filesystem-synchronised group. A new AppConfig.swift therefore must be added to the file-reference, App group, build-file, and Sources phase records or it is not compiled. Separately, TASK-001 describes APIBaseURL’s methods without public access, but AppConfig is in a separate app module and cannot call an internal member from APIClientLive. Either omission makes the proposed AppConfig.apiBaseURL reference fail at build time.
  Recommendation: Verdict: apply — amend TASK-001 to declare the cross-module resolver API public, and amend TASK-004 to enumerate/add the required PBX file-reference, group, build-file, and Sources-phase entries; retain the app build as a mandatory check.
- [high] Resolver explicitly accepts cleartext HTTP for a physical/release configuration (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-001-apibaseurl-resolver-in-apiclientlive-with-simulator-fallback-tests.md:13-34)
  The resolver’s stated contract accepts any http(s) URL, and its acceptance matrix requires http://192.168.0.10:8000 to resolve regardless of fallback state. The same plan says production ingress is HTTPS and deliberately excludes ATS exceptions. Current Info.plist contains no ATS exception. Thus a Release/device configuration accepted by the resolver can either fail every request under ATS or, if an exception is later introduced, send the bearer token over cleartext. This violates the stated production transport boundary rather than merely leaving an invalid URL unconfigured.
  Recommendation: Verdict: apply — update PLAN.md, RESEARCH.md, TASK-001, TASK-004, and TASK-005 so non-simulator configurations require HTTPS; permit localhost/HTTP only on the explicit DEBUG+simulator path and add tests proving Release/device resolution rejects cleartext URLs.
- [high] The plan treats the primary runtime acceptance test as non-blocking (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-004-composition-root-wiring-appconfig-info-plist-key-api-base-url-build-setting-explicit-apiclient.md:30-41)
  The epic requires a release/live-DEBUG build to reach the configured server on a physical device and says to show a real-host request log. TASK-004 instead says the device demonstration is “not a blocker for landing,” while TASK-005 only asks for an unspecified manual smoke test and allows criteria to be listed as CI-pending. Build success plus inspecting Info.plist proves substitution, not that the launched app uses the injected client or can connect through the actual TLS/ingress path. A shipping regression in the composition root, scheme/configuration, or device transport path can therefore pass every mandatory gate.
  Recommendation: Verdict: apply — update PLAN.md, TASK-004, and TASK-005 to make the physical-device probe and sync against the configured HTTPS host a release gate, with captured request-host evidence; if the owner cannot perform it yet, defer shipping rather than marking the phase production-ready.

Next steps:
- Revise the affected plan tasks before implementation, then re-review the updated acceptance and validation gates.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | AppConfig wiring can't compile: pbxproj file registration missing + resolver not public | high | apply | Verified: zero synchronized groups in pbxproj; cross-module call needs `public` | TASK-001:Files, TASK-004:Files, PLAN.md:Risks, RESEARCH.md |
| 2 | Resolver accepts cleartext http off-simulator, contradicting HTTPS ingress + no-ATS-exception posture | high | apply | Correct — https-only whenever the insecure fallback is off; tests pin it | TASK-001:Files/Acceptance, PLAN.md:Scope/Decisions/Acceptance |
| 3 | Primary runtime acceptance (device probe) treated as non-blocking | high | apply (partial) | Applied: a simulator runtime demonstration (`.http` log showing the configured host end-to-end) becomes a mandatory TASK-004/TASK-005 gate. The *physical-device* probe stays owner-CI-pending: this pipeline has no access to the owner's phone or server, and the epic run was ordered autonomously (--zte); the epic acceptance box stays unticked so the phase is not misreported as device-demonstrated | TASK-004:Acceptance/Notes, TASK-005:Steps, PLAN.md:Decisions/Acceptance |
