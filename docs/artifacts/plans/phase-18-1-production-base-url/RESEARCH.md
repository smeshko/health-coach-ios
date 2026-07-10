# Research: Production base-URL seam

Curated findings only — no raw conversation transcripts.

## Key Files & Directories

- `Sources/Clients/APIClient/Live/APIClient+Live.swift` — the CR-1 line: `live(baseURL: URL =
  URL(string: "http://localhost:8000")!, ...)`; `liveValue { live() }` ships the default.
- `App/CoachApp.swift` — composition root; `apiClient` is NOT set explicitly today (auto-
  resolves via `DependencyKey` in the Live target). Seeding call site for first-launch default.
- `Sources/Clients/APIClient/Interface/APIClient.swift` / `APIError.swift` — Sendable struct of
  six concrete closures; `.transport(String)` is the natural "not configured" error carrier
  (repos already map it; adding an enum case would ripple through exhaustive mappers).
- `Sources/Clients/DevSettings/Sources/DevSettings+FirstLaunch.swift` — DEBUG-only seed
  `mock=false` (live) on first launch; its doc comment already flags the localhost
  contradiction this phase resolves.
- `Sources/Clients/DevSettings/Sources/RoutedRepository.swift` — documents that every repo
  `routed(_:)` does `let live = Self.live` at construction: `apiClient.liveValue` resolves
  during `prepareDependencies` **even in mock mode**.
- `App/Info.plist` — partial plist merged via `GENERATE_INFOPLIST_FILE = YES` +
  `INFOPLIST_FILE = App/Info.plist` (pbxproj ~lines 307/337, two config blocks). No xcconfig
  files exist anywhere in the project.
- `backend/RUNBOOK.md` §4 — production ingress is cloudflared tunnel + custom domain (HTTPS at
  the edge, app on loopback `127.0.0.1:8000`); hostname/token are env-only, never committed.

## Architecture Facts

- Eager live construction means an unconfigured device build must NOT trap at dependency-
  resolution time → the failure mode has to be a throwing client, not `fatalError`.
- `$(VAR)` build-setting substitution works inside the partial Info.plist → a User-Defined
  `API_BASE_URL` setting (both config blocks) feeding an `APIBaseURL` plist key is the
  cheapest owner-editable seam.
- The pbxproj uses ordinary PBXGroup/PBXFileReference records (zero
  `PBXFileSystemSynchronizedRootGroup`), so a new App-target source file needs four records
  (file reference, build file, group child, Sources-phase entry — mirror `AppDelegate.swift`,
  ids in the `CA…` style).
- ATS: production URL is https → no exception needed; localhost loopback is ATS-exempt and
  already in daily simulator use.
- App-target files are not unit-testable (tests run via the CoachKit-Package SwiftPM scheme) →
  resolver logic must live in a package target (`APIClientLive`), `App/AppConfig.swift` stays
  a thin Bundle.main reader.

## Constraints

- The repo must not carry a real hostname (self-hosted access posture) → `API_BASE_URL` ships
  empty; owner sets it locally in Xcode build settings.
- `sim-unit-tests-must-pass` (memory): all unit tests green on the iOS sim. `Bundle.main` in
  SwiftPM tests is the test runner (no `APIBaseURL` key) → `liveValue` under test must keep
  resolving via the DEBUG+simulator localhost fallback (unchanged behaviour).
- Existing `APIClient.live(` call sites in tests (`TransportTests.swift:26`,
  `TransportLoggingTests.swift:19`) pass explicit arguments → removing the default parameter
  is compile-safe there.
- `DevSettingsLiveTests.swift:58/69` pin current seeding semantics; they gain the
  `liveBackendConfigured:` argument and a third (unconfigured → mock) case.

## Useful Commands

```bash
make test                    # host swift test (full package suite)
make lint                    # swiftlint --strict
xcodebuild -project CoachApp.xcodeproj -scheme CoachApp \
  -destination 'generic/platform=iOS Simulator' build   # app-target compile gate (TASK-004)
```

## Uncertainty

- Exact scheme name for the app build — resolve in TASK-004 via `xcodebuild -list` (the
  ios-build skill auto-detects; package tests use the shared CoachKit-Package scheme).
- No GitHub CI on the repo (merged PRs show zero checks) — the land workflow's CI watch will
  see no checks; local `make test`/`make lint` are the real gates.

## References

- `docs/artifacts/audits/AUDIT-2026-07-05.md` — Reliability lens, CR-1 [Critical].
- `docs/artifacts/epics/18-run-on-device.md` — Phase 18.1 goal/criteria.
- Memory: `release-readiness-audit-2026-06-18` (CR-1 origin), `audit-scope-personal-app`.
