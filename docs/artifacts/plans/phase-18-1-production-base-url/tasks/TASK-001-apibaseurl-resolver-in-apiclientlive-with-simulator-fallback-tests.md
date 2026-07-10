# TASK-001: APIBaseURL resolver in APIClientLive with simulator fallback + tests

Depends on: None
Suggested commit: `feat(api): add APIBaseURL resolver with DEBUG-simulator localhost fallback`

## Goal

A pure, unit-tested resolver that turns the raw configured value (Info.plist string) into the
base URL, with the localhost fallback expressible ONLY on the DEBUG+simulator path.

## Files

- `Sources/Clients/APIClient/Live/APIBaseURL.swift` (new) — `public enum APIBaseURL` with
  **public** members (AppConfig in the separate app module calls them — validation round-1 #1):
  - `public static func resolve(configuredValue: String?, allowInsecureFallback: Bool) -> URL?`
    — pure core: trims whitespace; empty/nil/unsubstituted (`$(API_BASE_URL)`) → fallback
    `http://localhost:8000` iff `allowInsecureFallback`, else nil; otherwise must parse as a
    URL with a host and an **https** scheme — plain `http` is accepted only when
    `allowInsecureFallback` is true (DEBUG+simulator dev loop). With the fallback OFF,
    loopback hosts are rejected even over https — classify, don't string-compare three
    values (validation round-2 #3 + round-3 #2): case-insensitive host, trailing dot
    stripped, reject `localhost`, any IPv4 literal in `127/8` (prefix `127.`), IPv6
    loopback `::1`/`[::1]`, and IPv4-mapped loopback (`::ffff:127.…`) — a release build
    must never target device loopback. Anything else → nil (invalid ≡ unconfigured — never
    a bad URL, never cleartext to a real device/release build; validation round-1 #2).
  - `public static func resolve(bundle: Bundle) -> URL?` — convenience reading the
    `"APIBaseURL"` Info.plist key and computing `allowInsecureFallback` as
    `#if DEBUG && targetEnvironment(simulator)` → true, else false.
- `Sources/Clients/APIClient/Tests/APIBaseURLTests.swift` (new) — Swift Testing
  (`import Testing`, `import Foundation`, `test_` prefix per repo convention).

## Acceptance

- [ ] Valid `https://coach.example.com` resolves regardless of the fallback flag;
  `http://192.168.0.10:8000` resolves ONLY with `allowInsecureFallback: true` and is nil
  otherwise (cleartext never reaches a device/release configuration).
- [ ] nil / empty / whitespace / literal `$(API_BASE_URL)` → localhost:8000 when
  `allowInsecureFallback: true`, nil when false.
- [ ] Garbage (`"not a url"`, `"ftp://x"`, scheme-less `"coach.example.com"`) → nil off-
  fallback (and localhost is NOT substituted for garbage even with fallback allowed — garbage
  means misconfigured, return nil so the caller surfaces it).
- [ ] Tests assert the resolver can never return a localhost/loopback URL **or any http URL**
  when `allowInsecureFallback` is false — the CR-1 + transport-boundary pin. Table-driven
  negative matrix includes: `https://localhost`, `https://localhost.`, `https://127.0.0.1`,
  `https://127.0.0.2`, `https://[::1]`, `https://[::ffff:127.0.0.1]` (round-3 #2).

Evidence: `swift test --filter APIBaseURLTests` output, all green.

## Steps

### RED
- [ ] Write `APIBaseURLTests` covering the matrix above; fails to compile (no resolver yet).

### GREEN
- [ ] Implement `APIBaseURL` in the Live target; tests pass.

### REFACTOR
- [ ] `make lint` clean; doc comment states the CR-1 contract (localhost only behind
  DEBUG+simulator).

## Notes

Decision fixed in PLAN.md: garbage input yields nil (unconfigured), not a trap — the throwing
`.unconfigured` client added in TASK-002 is the loud surface. Keep the enum caseless
(namespace only).
