# TASK-005: Snapshot writer hook in BriefRepositoryLive + composition-root install

Depends on: TASK-001,TASK-002
Suggested commit: `feat(sync): mirror the daily brief into the widget snapshot on cache write`

## Goal

Fire the widget-snapshot mirror from the single place the daily-brief cache is written
(`dailyBriefPolicy`), install the live client at the composition root, and link the new product into the
app target — verified by a recording-client unit test and a compile-only sim build.

## Files

- `Sources/Repositories/BriefRepository/Live/DailyBriefPolicy.swift` — edit `dailyBriefPolicy(refresh:)`:
  add `@Dependency(\.widgetSnapshot) var widgetSnapshot` (interface only — the LogClient-in-repo-live
  precedent, Package.swift BriefRepositoryLive comment) and, immediately after the successful
  `database.write { try DailyBriefRecord(domain: domain).save(db) }`, `await
  widgetSnapshot.updateDailyBrief(domain)` with a short comment (the 21.1 mirror; non-throwing by
  contract so the brief path cannot fail on it — DECISIONS D6). `cachedDailyBriefPolicy` untouched (pure
  peek). The weekly path is untouched (21.4 owns its hook).
- `Package.swift` — edit target `BriefRepositoryLive`: add dependency `WidgetSnapshotClient` with a
  house-style comment; edit test target `BriefRepositoryLiveTests`: add `WidgetSnapshotClient`.
- `Sources/Repositories/BriefRepository/Tests/BriefRepositoryLiveTests/WidgetSnapshotMirrorTests.swift` —
  new (host, Swift Testing, existing target): with a stubbed APIClient + in-memory Database
  (CoachTestSupport helpers, same rig as the existing cache-policy tests) and an overridden
  `\.widgetSnapshot` whose `updateDailyBrief` records into a `LockIsolated([DailyBrief])`:
  - generate path (cache miss) → recorded once with the served brief;
  - `refresh: true` → recorded once;
  - pure cache hit (`refresh: false`, row present) → NOT recorded (the snapshot was mirrored when that
    row was written — DECISIONS D6);
  - API-error path → NOT recorded.
  Existing suites stay green un-overridden via the TASK-001 no-op `testValue`.
- `App/CoachApp.swift` — edit: `import WidgetSnapshotClientLive` (composition-root-only import rule) and
  `$0.widgetSnapshot = .liveValue` inside `prepareDependencies` with a one-line comment (App
  Group mirror + timeline reload; written by BriefRepositoryLive).
- `CoachApp.xcodeproj/project.pbxproj` — edit (CA-id style, suffix range `…0201+` per RESEARCH): add
  `WidgetSnapshotClientLive` to the app target — one `XCSwiftPackageProductDependency`, one
  `PBXBuildFile`, one entry each in the `Frameworks` phase list and `packageProductDependencies`
  (mirror the `LogClientLive` foursome exactly). `DEVELOPMENT_TEAM` lines untouched.

## Acceptance

- [ ] The four `WidgetSnapshotMirrorTests` cases pass; the full existing suite stays green.
- [ ] `swift build`, `swift test`, `make lint` green.
- [ ] Compile-only app build succeeds: `xcodebuild -project CoachApp.xcodeproj -scheme CoachApp
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' build` (proves the pbxproj edit +
      the composition-root install compile).

Evidence: `swift test` output incl. the new suite; the xcodebuild BUILD SUCCEEDED line.

## Steps

### RED
- [ ] Add `WidgetSnapshotMirrorTests.swift` (fails: policy never calls the client).

### GREEN
- [ ] Add the dependency + the one-line hook in `dailyBriefPolicy`; Package.swift edges; composition-root
      install; pbxproj product link.

### REFACTOR
- [ ] Confirm hook placement is after the DB write and before `return` (a failed DB write must not
      mirror); `make lint`.

## Notes

- `routed(dev:)` means mock mode never hits the live policy — the widget mirror simply doesn't update in
  mock mode. Accepted (DEBUG-only dev tool); no code for it.
- Do NOT hook `cachedDailyBriefPolicy` — the peek is read-only by design (Phase 12.1 D1) and a cache hit
  must stay a zero-write path.
- On this task's first run in-app the acceptance criterion "refresh writes the JSON + log line" becomes
  demonstrable — the final task collects that evidence via verify-on-sim.
