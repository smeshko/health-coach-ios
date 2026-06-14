# TASK-001: Guard LogViewer reload against out-of-order double-refresh

Depends on: None
Suggested commit: `fix(settings): cancel in-flight LogViewer reload on re-trigger`

## Goal

Make the `LogViewerFeature` reload effect cancel-on-re-trigger so two rapid
`refreshTapped`/`onAppear` reloads can't land `logsLoaded` out of order (the one
reachable bug in the residual audit set — DECISIONS.md D1).

## Files

- `Sources/Features/SettingsFeature/Sources/DevMenu/LogViewerFeature.swift` — add a
  `private enum CancelID { case reload }` and append
  `.cancellable(id: CancelID.reload, cancelInFlight: true)` to the `.run` returned by the
  `case .onAppear, .refreshTapped:` arm (`:80-86`). No other arm changes (`clearTapped`
  stays uncancelled — it has its own reply).
- `Sources/Features/SettingsFeature/Tests/SettingsFeatureTests/LogViewerFeatureTests.swift`
  — add the out-of-order test (below); confirm the existing `onAppear`/`refreshTapped`/
  `clearTapped` tests still pass unchanged.

## Acceptance

- [ ] A second `refreshTapped` while the first reload is in flight cancels the first;
      only the latest `logsLoaded` is received (new test green).
- [ ] Existing LogViewer tests (`test_onAppear_loadsParsesAndAnchorsDate`,
      `test_refreshTapped_reloadsLines` if present post-11.6, `test_clearTapped_*`,
      `filteredEntries` tests) stay green.
- [ ] `make lint` clean (no nested-type violation introduced).
- [ ] Host + sim suites green.

## Steps

### RED
- [ ] Write the race test: stub `\.log.readRecent` so the first call suspends on a gated
      continuation (or a `TestClock`) and returns line set A, the second returns line set
      B; send `.refreshTapped` twice; advance/resume; assert exactly one
      `.logsLoaded(B)` lands and `state.entries` reflects B. Against the current
      uncancelled effect this fails (both A and B land).

### GREEN
- [ ] Add the `CancelID` enum and `.cancellable(id:, cancelInFlight: true)`.

### REFACTOR
- [ ] Re-run the full LogViewer test file; `make lint`; host + sim suites.

## Notes

`readRecent()` is a synchronous closure called inside `.run`; to make the first reload
observably in-flight the test must gate the stub (an `AsyncStream`/continuation the test
signals, or a `TestClock` the effect awaits). Keep it deterministic — no wall-clock
sleeps (RESEARCH.md Constraints).
