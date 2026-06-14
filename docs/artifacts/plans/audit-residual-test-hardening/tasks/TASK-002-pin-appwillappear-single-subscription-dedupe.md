# TASK-002: Pin _appWillAppear single-subscription dedupe

Depends on: None
Suggested commit: `test(app): pin single-subscription dedupe on repeated _appWillAppear`

## Goal

Characterize (pin) the already-correct behavior that re-sending `._appWillAppear` does
not stack a second session-stream subscriber: one delivered event after a double
subscribe is received exactly once. Test-only — no production change.

## Files

- `Sources/Features/AppFeature/Tests/AppFeatureTests/AppFeature401Tests.swift` — add the
  dedupe test alongside the existing session-stream tests (the file already stubs
  `apiClient.sessionEvents()`); a new file is fine if cleaner.

## Acceptance

- [ ] Sending `._appWillAppear` twice then yielding ONE `.unauthorized` event results in
      exactly one received `._sessionEvent(.unauthorized)` (the exhaustive `TestStore`
      fails on a second). Pins the `.cancellable(id: .sessionStream, cancelInFlight:
      true)` contract at `AppFeature+SessionRouting.swift:12-23`.
- [ ] No production code changes.
- [ ] Host + sim suites green.

## Steps

### RED
- [ ] Write the test: a controllable `sessionEvents()` stream (an `AsyncStream` whose
      continuation the test holds); `send(._appWillAppear)` twice; yield one
      `.unauthorized`; assert a single `._sessionEvent` receive + the swap to
      `.onboarding`; `finish()` cleanly.

### GREEN
- [ ] n/a — behavior already correct (`cancelInFlight: true`); the test documents/locks
      it. (Characterization guard: the "RED" is that the test expresses the invariant and
      compiles.)

### REFACTOR
- [ ] Confirm the existing 401 tests still pass (shared stub); host + sim suites.

## Notes

The "double-subscribe dedupe" half of audit gap #8. Value is a regression tripwire — a
refactor dropping the cancellation flips this test red.
