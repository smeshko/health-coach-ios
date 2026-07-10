# TASK-002: AppFeature: three-state token restore (present/absent/read-failed)

Depends on: None
Suggested commit: `fix(app): keychain read error at launch is not "no token"`

## Goal

A thrown Keychain read at launch keeps a token-holding owner on `.main` instead of
stranding them at onboarding; only a confirmed no-token launch swaps.

## Files

- `Sources/Features/AppFeature/Sources/AppFeature.swift` —
  - `public enum TokenRestore: Equatable, Sendable { case present, absent,
    readFailed(String) }` — PUBLIC: `AppFeature.Action` is public, so an internal nested
    payload type is an access-control compile error (validation round-2 #1). String =
    error description for the log; keep the ACTION name `_tokenChecked` — the payload-free
    `.tca` log renders the case label only.
  - `_restoreSession` effect: do-catch — `read()` success → `.present`/`.absent` by
    trimmed-emptiness (same rule as today); catch → `.readFailed("\(error)")`.
  - `_tokenChecked` arm: `.present` → stay + `todayRoot(.onAppOpen)` (unchanged);
    `.absent` → onboarding swap (unchanged, only-from-`.main` guard kept);
    `.readFailed` → clear `isRestoringSession`, STAY PUT (no route change from `.main`),
    log distinctly on the always-on `.http` category (round-1 #1) — "Launch token read
    FAILED — staying on main" — and still dispatch `todayRoot(.onAppOpen)`. Outcome
    honesty (round-1 #3): under a TRANSIENT failure the next request's per-call
    `tokenClient.read()` succeeds and everything proceeds; under a PERSISTENT keychain
    failure no request can even be built (Transport reads the token before sending), so
    there is no 401 to route — the user stays on `.main` in a DEGRADED route whose exact
    surface varies (round-3 #3): a check-in-gated morning shows the check-in card first;
    a cache-hit launch renders cached content with the background failure deliberately
    quiet; a cache-miss sync shows the error state. In every variant the always-on
    `.http` log names the keychain cause — that log is the reliable trace, not any one
    screen. Relaunch recovers transients. Comments must describe exactly this (no blanket
    "sync-error surface" claim, no 401-stream claim); a dedicated recoverable
    auth/persistence error state with foreground re-read is DEFERRED (single-owner app,
    rare device-level failure).
- `Sources/Features/AppFeature/Tests/AppFeatureTests/AppFeatureSwitchTests.swift` —
  - existing parameterized nil/"" test: receive shape becomes `\._tokenChecked, .absent`.
  - existing present-path assertions: `.present`.
  - new: throwing `tokenClient.read` → `.readFailed`, route stays `.main`,
    `isRestoringSession` false, `.onAppOpen` dispatched, no onboarding swap.
  - new log-capture assertion (round-2 #2): the `.readFailed` arm emits its record on
    `.http` (capture via the existing test log harness — same pattern as
    ActionLoggingTests), message names the failure without raw error payloads beyond the
    status description.
- `Sources/Features/AppFeature/Tests/AppFeatureTests/ActionLoggingTests.swift:29` —
  `._tokenChecked(hasToken: true)` → `._tokenChecked(.present)`; the asserted `.tca` label
  `"_tokenChecked"` is unchanged.

## Acceptance

- [ ] Throwing `read()` → route stays `.main`, restore overlay lifts, cache-first open
  dispatched, distinct log line (TestStore).
- [ ] nil/"" → `.absent` → onboarding swap (existing behaviour, new shape).
- [ ] Non-empty token → `.present` → unchanged happy path.
- [ ] `swift test --filter AppFeatureTests` + full `make test` + `make lint` green.

Evidence: test output transcript.

## Steps

### RED
- [ ] The readFailed TestStore test + reshaped receive assertions (fail to compile against
  the Bool payload).

### GREEN
- [ ] Enum, do-catch effect, three-arm reducer.

### REFACTOR
- [ ] Header doc comment (line ~10) updated: "falls back to `.onboarding` only when no
  bearer token is CONFIRMED absent; a read error stays put"; lint clean.

## Notes

Do NOT probe the network in the restore path (unchanged §13 design — launch works
offline). If other tests construct `_tokenChecked` (grep before starting), reshape them
mechanically. The 401-routed onboarding swap (`_sessionEvent`) is untouched.
