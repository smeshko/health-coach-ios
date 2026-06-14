# Research: Audit residual test hardening — races + entry-point coverage

Curated findings only — no raw conversation transcripts. Verified against the
post-Epic-11 / post-12.3 tree (staging @ `9e8ec22`, 2026-06-13).

## Key Files & Directories

- `Sources/Features/SettingsFeature/Sources/DevMenu/LogViewerFeature.swift:80-86` — the
  `case .onAppear, .refreshTapped:` arm sets `isLoading`/`referenceDate` then returns
  `.run { await send(.logsLoaded(log.readRecent())) }` with **no `.cancellable`**. No
  `CancelID` enum exists in this reducer. → TASK-001 (the one fix).
- `Sources/Features/AppFeature/Sources/AppFeature+SessionRouting.swift:12-23` —
  `case ._appWillAppear:` opens the session stream and returns
  `.cancellable(id: CancelID.sessionStream, cancelInFlight: true)`. Dedupe is **already
  correct**; only a pinning test is missing. → TASK-002.
- `Sources/Features/AppFeature/Sources/AppFeature.swift:52` — `enum CancelID { case
  sessionStream }` (the `appWork` case was deleted in Epic 11.1).
- `Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift:26-85` —
  `runSync()`: reads the watermark (`:35-37`), captures `readInstant = date.now`
  (`:41`), reads HK deltas / builds / POSTs, then **on success** writes the watermark
  (`:75-82`). No in-flight guard; two concurrent calls both read the old anchor and both
  write their own `readInstant`. → TASK-003 (characterize).
- `Sources/Clients/Database/Sources/DatabaseLive.swift:10-14` — `makeLive(path:)` opens a
  `DatabaseQueue(path:)` and runs `migrator.migrate(queue)`; `makeInMemory()` (`:17-21`)
  is the only one the tests use today. `liveValue` (`:40-42`) is `makeLive`. → TASK-004.
- `Sources/Clients/HealthKitClient/Live/HKTypeCatalog.swift:45-46` —
  `HKTypeCatalog.allReadTypes: Set<HKObjectType>` (the authorization read set);
  `Sources/Clients/HealthKitClient/Live/HKSampleMapping.swift:10` — each spec carries a
  `sampleType: HKSampleType`; `HKDeltaReads.swift:31` iterates
  `HKSampleMapping.recordQuerySpecs`. Nothing ties the two catalogs together. → TASK-005.
- `Sources/Clients/LogClient/Live/LogFileWriter.swift:14` — `public actor LogFileWriter`;
  `enqueue(_:)` is `nonisolated` (`:95`) feeding a single `AsyncStream` consumed by one
  actor-isolated loop "so lines never interleave" (doc `:6`). No concurrency test pins
  it. → TASK-006.
- `Sources/Features/SettingsFeature/Tests/SettingsFeatureTests/DevMenuFeatureTests.swift:136`
  — `test_viewLogsTapped_presentsAndDismissesLogViewer` only asserts the `@Presents`
  setter + `ifLet` dismiss (library plumbing). → TASK-007.
- `Sources/Core/CoachCore/Tests/CalendarTests.swift:93` —
  `testUseEuropeSofiaPinsCalendarAndTimeZone` reads back what `useEuropeSofia()` set
  (`calendar.timeZone.identifier == "Europe/Sofia"`), restating the setter. → TASK-007.

## Architecture Facts

- Repo is 100% Swift Testing (`import Testing`, `@Test`, `#expect`). Keep the `test_`
  prefix; add explicit `import Foundation`. Features use TCA `TestStore` (exhaustive).
- Epic 11.7 moved topology: `CheckInRepository`/`StrengthTestRepository` live in
  `Sources/Repositories/LocalRepositories/`; `Database` and `TokenClient` are single
  (merged) targets. Database tests are at `Sources/Clients/Database/Tests/`.
- `Database` exposes `DatabaseClient.makeInMemory()` (via `Database+TestValue.swift`) and
  the migrator runs inside `makeLive`/`makeInMemory`, not in `make(queue:)`.
- Migration-test precedent: `StrengthWeekMigrationTests.swift` and
  `DomainBodyCacheMigrationTests.swift` (both under Database/Tests) show the
  build-through-vN-then-assert pattern.
- HealthKit Live tests already construct HK types without entitlement
  (`HKReadSetCoverageTests.swift` references `recordQuerySpecs`); HK types are
  constructible in tests.
- Sim unit tests must all pass on the pinned canonical sim (iPhone 17 Pro / OS 26.0);
  host-only tests that can't run on sim are deleted by precedent — keep the new tests
  sim-safe.

## Constraints

- Concurrency tests must be deterministic: use `TestClock` / gated continuations, never
  `Task.sleep` wall-clock. Assert invariants (single delivery, whole lines), not timing.
- The LogViewer fix is the ONLY production change; everything else is test-only.
- `make lint` must stay green (a prior nesting violation was fixed in 11.7; don't
  reintroduce nested types in test files).

## Useful Commands

```bash
# host suite
swift test
# sim unit tests (pinned canonical sim)
xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace -scheme CoachKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
# lint
make lint
```

## Uncertainty

- **Whether the concurrent-`sync()` race is reachable at all** — resolved: the only
  caller (TodayFeature orchestration) serializes via `cancelInFlight`, so it is not
  reachable in-app today. Decision: characterize current behavior, do not serialize
  (DECISIONS.md D2). If a second caller is ever added, the pinned test documents what
  would change.
- **HealthKit run-gate (host vs sim)** — resolved by mirroring `HKReadSetCoverageTests`
  exactly; if that suite runs in a given environment, the new assertion runs with it.

## References

- [test-audit-2026-06-12](../../test-audit-2026-06-12.md) — §6 gaps #8 (concurrency),
  module-level Database/HealthKit/LogClient gaps, and the WEAK verdicts; this plan is its
  residual-coverage tail.
- [Epic 11](../../epics/11-simplification.md) — absorbed the rest of the audit; this plan
  is the explicitly-deferred remainder (merged Epic 11 noted the concurrent-sync race as
  a deferral).
