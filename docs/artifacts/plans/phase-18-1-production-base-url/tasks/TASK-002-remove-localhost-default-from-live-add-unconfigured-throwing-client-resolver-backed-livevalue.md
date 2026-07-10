# TASK-002: Remove localhost default from live(); add unconfigured throwing client; resolver-backed liveValue

Depends on: TASK-001
Suggested commit: `fix(api): drop shipped localhost default; unconfigured client throws (CR-1)`

## Goal

`http://localhost:8000` can no longer ship implicitly: `live(baseURL:)` requires the URL, and
an unresolvable configuration yields a client whose calls throw a clear error instead of
silently targeting localhost (or crashing at launch).

## Files

- `Sources/Clients/APIClient/Live/APIClient+Live.swift` —
  - remove the `= URL(string: "http://localhost:8000")!` default from `live(baseURL:...)`;
  - add `static let unconfigured: APIClient` — every throwing closure throws
    `APIError.transport("API base URL not configured — set API_BASE_URL in the CoachApp build
    settings")`; `sessionEvents` returns an immediately-finished `AsyncStream`;
  - `liveValue` becomes: `APIBaseURL.resolve(bundle: .main).map { live(baseURL: $0) } ??
    .unconfigured`.
- `Sources/Clients/APIClient/Tests/` (extend `APIBaseURLTests.swift` or new file) — tests for
  the unconfigured client.

## Acceptance

- [ ] `APIClient.live(` has no `baseURL` default; the package compiles (existing
  `TransportTests`/`TransportLoggingTests` pass explicit args — verify, don't weaken).
- [ ] `APIClient.unconfigured.probe()` (and `sync`) throw `APIError.transport` with the
  configuration message; `sessionEvents()` finishes immediately (no hang).
- [ ] `liveValue` cannot trap however resolution goes — eager `routed()` construction at the
  composition root stays launch-safe.

Evidence: `swift test --filter APIClient` output green; grep shows no `localhost:8000` outside
`APIBaseURL.swift`'s fallback + tests.

## Steps

### RED
- [ ] Tests for `unconfigured` throwing semantics + stream finishing.

### GREEN
- [ ] Implement; remove the default parameter; rewire `liveValue`.

### REFACTOR
- [ ] Update the `APIClient+Live` doc comments to state the resolution chain (explicit
  composition-root injection → plist resolver → unconfigured-throwing).

## Notes

Do NOT add an `APIError` case — reuse `.transport(String)` (PLAN.md Decisions; exhaustive
mappers in repos would ripple). Host-vs-sim: `make test` runs on macOS where
`targetEnvironment(simulator)` is false, so `liveValue` there resolves `.unconfigured` — fine
as long as no host test invokes `liveValue`'s endpoints (none do today; they build clients
explicitly). If one surfaces, prefer fixing the test to inject explicitly over widening the
fallback. Leave `DevSettings+FirstLaunch.swift`'s stale localhost NOTE to TASK-003 (single
owner for that file).
