# Adversarial Validation — Round 3

**Run:** 2026-07-10
**Plan:** phase-18-1-production-base-url
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)
**Prior rounds in scope:** validation/round-1.md, validation/round-2.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: round-2’s loopback fix is incomplete, and the planned unconfigured path still hides a deployment misconfiguration from both the user and HTTP logs.

Findings:
- [high] Unconfigured backend is presented as an invalid token, not a configuration failure (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-002-remove-localhost-default-from-live-add-unconfigured-throwing-client-resolver-backed-livevalue.md:16-20)
  TASK-002 makes every unconfigured request throw a transport string, but does not add a presenter or logging path. The existing Connect reducer catches every probe failure, clears the token, and the view always displays the fixed token-rejected message. Because this client bypasses Transport, it also emits no `.http` diagnostic. An empty/mis-substituted production URL therefore looks exactly like a bad token and is difficult to recover or diagnose, contrary to the plan’s “loud” failure decision.
  Recommendation: Add a typed configuration-failure signal and an explicit onboarding/error presentation plus a safe diagnostic log; test that an unconfigured build neither clears a valid-looking token as “invalid” nor hides the missing-base-URL cause.
- [medium] Loopback rejection still permits common loopback aliases (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-001-apibaseurl-resolver-in-apiclientlive-with-simulator-fallback-tests.md:19-22)
  The round-2 edit lists only `localhost`, `127.0.0.1`, and `::1`. It does not reject the rest of IPv4 loopback (`127.0.0.2` through `127.255.255.255`), trailing-dot aliases such as `localhost.`, or IPv4-mapped IPv6 such as `::ffff:127.0.0.1`. Those forms can still resolve to the device itself while `allowInsecureFallback` is false, violating the stated off-simulator no-loopback invariant.
  Recommendation: Classify IP literals rather than comparing three strings: reject all IPv4 127/8 addresses, IPv6 loopback, and IPv4-mapped loopback; normalize and reject localhost aliases. Add these variants to the table-driven negative matrix.
- [medium] Release configuration is required but never explicitly built or inspected (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-004-composition-root-wiring-appconfig-info-plist-key-api-base-url-build-setting-explicit-apiclient.md:37-46)
  The plan’s acceptance requires a release build to resolve the configured server, yet both prescribed `xcodebuild` checks omit `-configuration Release`; `xcodebuild build` defaults to Debug. The simulator runtime proof likewise exercises the override build without requiring the Release configuration. A typo or omission in the Release build-settings block can therefore leave the distributed app unconfigured while every listed gate passes.
  Recommendation: Require a separate `-configuration Release` simulator build with `API_BASE_URL` overridden and inspect that Release product’s Info.plist. Keep the owner-device run CI-pending as decided, but do not treat Debug substitution as Release evidence.
- [medium] The specified AppConfig source omits Foundation despite using Foundation types (docs/artifacts/plans/phase-18-1-production-base-url/tasks/TASK-004-composition-root-wiring-appconfig-info-plist-key-api-base-url-build-setting-explicit-apiclient.md:24-26)
  The exact new-file sketch imports only `APIClientLive` but declares `URL?` and calls `Bundle.main`. Foundation imports are not generally transitive through an imported package module, so this source can fail to compile before the resolver wiring is exercised. This is the same class of plan-level compile omission found in round 1.
  Recommendation: Specify `import Foundation` in `AppConfig.swift` and retain the app-target build check as the proof.

Next steps:
- Amend TASK-001’s loopback matrix and TASK-002’s unconfigured failure presentation before implementation.
- Add an explicit Release-configuration build/plist validation to TASK-004.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Unconfigured backend looks like an invalid token; no diagnostic path | high | apply (slim) + defer (presenter) | Applied: composition-root `.app` log line when the unconfigured arm is taken → diagnosable in the on-device log viewer. Deferred: typed config-failure signal + error presentation + Connect-clears-token interplay — Phase 18.3 owns exactly that Connect probe-failure/token bug; coupling it here mixes two audit fixes | TASK-004:Files, PLAN.md:Decisions |
| 2 | Loopback rejection misses 127/8, `localhost.`, IPv4-mapped IPv6 | med | apply | Classify hosts instead of comparing three strings; matrix extended | TASK-001:Files/Acceptance |
| 3 | Release configuration never explicitly built/inspected | med | apply | `-configuration Release` build + Release-product plist inspection added as acceptance | TASK-004:Acceptance |
| 4 | AppConfig sketch missing `import Foundation` | med | apply | Correct — Foundation is not transitively re-exported | TASK-004:Files |

**Round-3 note (protocol):** the shared protocol says round-3 applies normally stop for the
user. This run is explicitly autonomous (user order: no interview, best judgement). All four
round-3 findings are refinement-grade (imports, build configuration, alias matrix, one log
line), not structural plan defects — applied and concluded, no fourth round.
