# TASK-003: DevSettings first-launch seeding coherent with configured backend

Depends on: TASK-002
Suggested commit: `fix(devsettings): seed first-launch mock/live from backend configuredness`

## Goal

A fresh DEBUG install without a configured base URL seeds **mock** (usable app), not
guaranteed-failing live; with a configured URL the 2026-06-18 live-by-default behaviour is
preserved.

## Files

- `Sources/Clients/DevSettings/Sources/DevSettings+FirstLaunch.swift` — signature becomes
  `seedFirstLaunchDefault(liveBackendConfigured: Bool, defaults: UserDefaults = .standard)`;
  seeds `mock = !liveBackendConfigured` when nothing is persisted (still DEBUG-only, still
  write-once). Rewrite the doc comment: drop the stale localhost NOTE, state the coherence
  contract (live-by-default iff a live backend is configured; resolver owns what "configured"
  means).
- `Sources/Clients/DevSettings/Tests/DevSettingsLiveTests.swift` — update the two existing
  seeding tests to pass `liveBackendConfigured: true`; add
  `test_seedFirstLaunchDefault_seedsMockTrueWhenBackendUnconfigured` and keep the
  no-clobber test meaningful for both flag values.

## Acceptance

- [ ] `liveBackendConfigured: true` + nothing persisted → seeds `mock = false` (unchanged).
- [ ] `liveBackendConfigured: false` + nothing persisted → seeds `mock = true`.
- [ ] A persisted value is never clobbered by either flag value.

Evidence: `swift test --filter DevSettingsLiveTests` output green.

## Steps

### RED
- [ ] Extend/adjust the seeding tests for the new parameter + unconfigured case.

### GREEN
- [ ] Implement the parameter; update the doc comment.

### REFACTOR
- [ ] `make lint` clean; comment references PLAN.md decision, not implementation history.

## Notes

No default value for `liveBackendConfigured` — force the composition root (the only prod
caller, updated in TASK-004) to state it explicitly; tests pass it per-case. The unique
UserDefaults-suite isolation pattern from the existing tests must be kept (serialized suites,
see `epic9-phase9-1` memory gotcha).
