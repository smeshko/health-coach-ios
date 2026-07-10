# Plan: Production base-URL seam

Status: draft
Branch: fix/phase-18-1-production-base-url
Risk: medium
Epic: 18 — Make it run on device (audit wave 1) ([epic](../../epics/18-run-on-device.md))
Phase: 18.1 — Production base-URL seam
Linear: none
Created: 2026-07-10

## Goal

Close audit CR-1: inject the server base URL at the composition root (build-setting →
Info.plist → `AppConfig`) so a device build reaches the real self-hosted backend, and make it
impossible for the `http://localhost:8000` default to ship silently.

## Scope

- A pure, testable base-URL resolver in `APIClientLive` (`APIBaseURL`) with the localhost /
  cleartext-http fallback confined to DEBUG + simulator; off that path only https URLs
  resolve.
- Remove the `baseURL` default parameter from `APIClient.live(...)`; add an `.unconfigured`
  client whose requests throw a clear `APIError.transport` message (no launch crash — see
  Decisions).
- `liveValue` resolves through the resolver (Bundle.main) instead of hardcoding localhost.
- `DevSettings.seedFirstLaunchDefault` gains a `liveBackendConfigured:` input so a fresh
  DEBUG install without a configured URL seeds **mock**, not guaranteed-failing live.
- Composition root: `App/AppConfig.swift`, `APIBaseURL` Info.plist key backed by an
  `API_BASE_URL` build setting (pbxproj, Debug + Release), explicit
  `$0.apiClient = .live(baseURL:)` / `.unconfigured` in `CoachApp.prepareDependencies`.

## Out of Scope

- HealthKit read bounding (Phase 18.2), probe/Connect hardening (18.3), DB/token restore (18.4).
- ATS exceptions — the production ingress is HTTPS (cloudflared + custom domain, backend
  RUNBOOK §4); localhost loopback on simulator is ATS-exempt.
- Committing a real hostname — the owner sets `API_BASE_URL` locally in Xcode; the repo ships
  it empty by design (self-hosted, hostname kept out of git).
- Any change to coaching math, repos, or features.

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing findings: `routed(_:)` factories construct
`Self.live` **eagerly** even in mock mode, so an unconfigured device build must not trap at
dependency-resolution time — hence the throwing `.unconfigured` client instead of a
`fatalError`. The app target merges a partial `App/Info.plist` with generated keys
(`GENERATE_INFOPLIST_FILE = YES`), so a `$(API_BASE_URL)` substitution in the partial plist is
the cheapest owner-editable seam (no xcconfig files exist in the project today).

## Decisions

- **Throwing `.unconfigured` client, not `fatalError`** — `routed()` resolves live repos (and
  transitively `apiClient.liveValue`) eagerly even when mock mode is on; a trap would crash a
  fresh unconfigured install at launch. A client whose calls throw
  `APIError.transport("API base URL not configured — set API_BASE_URL in build settings")`
  is loud at first use, recoverable, and never silently localhost.
- **Reuse `APIError.transport`, no new enum case** — repositories map `APIError` exhaustively;
  a new case would ripple through mappers for zero user-visible gain.
- **Resolver lives in `APIClientLive`, thin `AppConfig` in App/** — package code is
  unit-testable via `swift test`; App-target files are not (tests run via the CoachKit-Package
  scheme). `AppConfig` only reads `Bundle.main` and delegates.
- **`API_BASE_URL` ships empty in the repo** — the hostname is deliberately not committed
  (RUNBOOK access posture). Empty resolves to: localhost on DEBUG+simulator, `.unconfigured`
  (throwing) everywhere else. Resolver unit tests pin that no build path yields localhost
  off-simulator — that is the "caught by a test" acceptance arm.
- **Seed mock on unconfigured DEBUG first launch** — reconciles the 2026-06-18 live-by-default
  seeding with CR-1: live-by-default only when a live backend is actually reachable-by-config;
  otherwise a fresh install lands in usable mock mode instead of a guaranteed-failing live run.
- **HTTPS-only off the DEBUG+simulator path** (validation round-1 #2) — the production ingress
  is HTTPS (cloudflared) and no ATS exception ships; accepting cleartext http for a device/
  release configuration would either fail under ATS or invite sending the bearer token in the
  clear. The resolver rejects non-https values whenever the insecure fallback is off.
- **Sim-runtime demonstration is the land gate; physical-device probe is owner CI-pending**
  (validation round-1 #3) — the pipeline cannot operate the owner's phone/server. TASK-004
  must show the launched app's `.http` log targeting the configured host on the simulator;
  the on-device probe/sync stays an unticked epic acceptance box for the owner.
- **Unconfigured diagnosis = throwing client + composition-root log line; no new error UI**
  (validation round-3 #1) — a dedicated configuration-failure presenter and the
  Connect-clears-token interplay are deferred: Phase 18.3 owns exactly that Connect
  probe-failure/token bug, and layering a presenter change into this phase would couple two
  audit fixes. The `.app` log line + the explicit `APIError.transport` message make the
  misconfiguration diagnosable from the on-device log viewer.

## Risks

- pbxproj hand-edit (2 config blocks + 4 file-registration records for `AppConfig.swift`;
  ordinary non-synchronized groups, validation round-1 #1) — mitigated: mirror
  `AppDelegate.swift`'s existing records, verified by an `xcodebuild` app build in TASK-004.
- Existing tests constructing `APIClient.live(` without `baseURL:` — checked: both call sites
  (`TransportTests`, `TransportLoggingTests`) pass explicit arguments; the removed default is
  compile-checked anyway.
- `liveValue` resolution in SwiftPM tests (Bundle.main = test runner, no plist key) — resolves
  via the DEBUG+simulator fallback to localhost, same behaviour as today; no test churn.

## Acceptance Criteria

- [ ] A release (and live-mode DEBUG) build resolves the APIClient to the configured server
  URL; with `API_BASE_URL` set, requests go to that host — unit-tested resolver + built app +
  a simulator runtime run whose `.http` log shows the configured host (TASK-004 evidence).
- [ ] No build path resolves to localhost — or any cleartext http URL — off DEBUG+simulator;
  pinned by resolver unit tests (the "caught by a test" arm); the default parameter is gone
  from `live(...)`.
- [ ] First-launch live/mock default is coherent with the configured URL: unconfigured DEBUG
  fresh install seeds mock; configured install seeds live (unit-tested).
- [ ] CI-pending (owner): on-device probe + sync against the real HTTPS backend (physical
  phone + self-hosted server; the epic's Validation step — the corresponding epic acceptance
  box stays unticked until demonstrated).

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [ ] TASK-001: APIBaseURL resolver in APIClientLive with simulator fallback + tests
- [ ] TASK-002: Remove localhost default from live(); add unconfigured throwing client; resolver-backed liveValue (depends on TASK-001)
- [ ] TASK-003: DevSettings first-launch seeding coherent with configured backend (depends on TASK-002)
- [ ] TASK-004: Composition-root wiring: AppConfig, Info.plist key, API_BASE_URL build setting, explicit apiClient (depends on TASK-003)
- [ ] TASK-005: Final Validation
