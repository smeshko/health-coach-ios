# Research: Widget infrastructure — App Group, CoachWidgets extension, snapshot pipeline

Curated findings only — no raw conversation transcripts.

## Key Files & Directories

- `Sources/Repositories/BriefRepository/Live/DailyBriefPolicy.swift` — `dailyBriefPolicy(refresh:)` is the
  single daily cache writer: on the generate path it maps DTO→domain (`domainDailyBrief`) then
  `database.write { DailyBriefRecord(domain:).save(db) }` and returns. This is the hook point for the
  widget-snapshot mirror. `cachedDailyBriefPolicy()` is a pure peek — never writes, must NOT be hooked.
- `Sources/Repositories/BriefRepository/Live/WeeklyPlanPolicy.swift` — same shape for weekly;
  `isoWeekKey(_:)` formats `ISOWeek` → `"%04d-W%02d"` (`2026-W07`). The canonical week-string format the
  snapshot's `isoWeek` field must match (21.4 hooks this path; 21.1 only fixes the format).
- `Sources/Repositories/BriefRepository/Live/SyncGate.swift:12` — `sofiaToday()` (module-internal): start
  of today in `Calendar.europeSofia`. The snapshot's staleness helper mirrors this day-key logic.
- `Sources/Clients/LogClient/` — THE interface/live split to mirror: `Interface/` target `LogClient`
  (closure struct + `TestDependencyKey` testValue + `DependencyValues` accessor), `Live/` target
  `LogClientLive` (`extension LogClient: DependencyKey { liveValue }`). Two host test targets nested under
  `Tests/LogClientTests` + `Tests/LogClientLiveTests` (the multi-test-target layout, Package.swift:706-733).
- `Sources/Models/DomainModels/Sources/` — all needed types are already `Codable + Equatable + Sendable`:
  `DailyBrief` (date, readiness, safetyGate, session, macroFocus, intakeYesterday, generatedAt),
  `Readiness`/`SafetyGate` (Readiness.swift), `SessionBlock`/`PlannedSession` (Session.swift, PlannedSession
  carries `suggestedDay`), `MacroFocus` (Nutrition.swift), `IntakeSummary`/`IntakeVsTarget` (Intake.swift),
  `WeeklyBudgets` (has `deload: Bool`) / `WeeklyTargets` (Nutrition.swift), closed enums all
  `String`-raw `Codable` (ClosedEnums.swift). The snapshot schema can embed them directly — no mirror types.
- `Sources/Core/CoachCore/Sources/Calendar+EuropeSofia.swift` — `Calendar.europeSofia`; `ISOWeek.swift` —
  `ISOWeek.containing(_:)` uses `@Dependency(\.calendar)` (NOT usable in the extension process where no
  `prepareDependencies` runs — staleness helpers must take an explicit `Calendar` parameter instead).
- `Sources/Features/AppFeature/Sources/AppFeature.swift` — reducer routing precedent:
  `notificationOpened(identifier:)` (line 204) guards `case var .main(main) = state.route`, mutates
  `main.selectedTab`, re-embeds. Deep-link handling copies this shape. `MainTabs.Tab` = `.today/.weekly/.settings`.
- `Sources/Features/AppFeature/Sources/AppView.swift` — the single non-re-mounting outer `ZStack` with
  `.task` (line 46); `.onOpenURL` goes on the same container.
- `Sources/Features/TodayFeature/Sources/TodayFeature.swift` + `BriefViewState.swift` — the check-in flow
  is the Today tab's own gate: `BriefViewState.checkInRequired` renders the check-in card
  (`CheckInComponent`) whenever today (Sofia) is unlogged. A "check-in" deep link therefore only needs to
  land on the Today tab; the gate surfaces the flow.
- `Sources/Core/CoachTestSupport/Sources/SnapshotConvention.swift` — `assertCoachSnapshot(of:)`: light+dark
  on `coachReferenceDevice` (`.iPhone13`), whole file `#if canImport(UIKit)`. Snapshot test targets follow
  `Sources/<Layer>/<Module>/Tests/<Module>SnapshotTests/` + `exclude: ["__Snapshots__"]`.
- `Makefile:9` — `SNAPSHOT_TARGETS` is the exhaustive `-only-testing:` list; a new snapshot target MUST be
  appended or it never runs on the pinned sim.
- `CoachApp.xcodeproj/project.pbxproj` — 458 lines, hand-authored `CA` + 24-hex object IDs; single
  `PBXNativeTarget` (CoachApp, `CA0000000000000000000005`); package linked via
  `XCLocalSwiftPackageReference "."` + `XCSwiftPackageProductDependency` per product;
  `DEVELOPMENT_TEAM = GR9SJM3FZP` + `CODE_SIGN_ENTITLEMENTS = App/CoachApp.entitlements` in BOTH target
  configs (lines 314-317, 346-349). Used ID suffixes: `01–16`, `20–2C`, `30–3C`, `A1`, `B1–B2`, `F0–F3`.
  The `…0100`+ and `…0200`+ suffix ranges are free for new objects.
- `App/CoachApp.entitlements` — currently HealthKit only; gains the App Group.
- `App/Info.plist` — hand-authored keys merged with `GENERATE_INFOPLIST_FILE = YES`; `CFBundleURLTypes`
  goes here (same merge mechanism as `UILaunchScreen`/`APIBaseURL`).
- `App/CoachApp.swift` — composition root; `prepareDependencies` installs every live value. The
  `widgetSnapshot` live install lands here.
- `Package.swift` — products list = "EXACTLY the modules the app target imports" (comment, lines 11-14);
  the widget extension becomes a second product consumer, so the comment needs a one-line amendment.
  `platforms: [.iOS(.v26), .macOS(.v14)]` — every new target must compile for the macOS host
  (`swift build`/`swift test`), so WidgetKit-touching code needs `#if canImport(WidgetKit)` guards.

## Architecture Facts

- Layer rules (ARCHITECTURE, restated across Package.swift comments): snapshot writer = a client under
  `Sources/Clients/`; repositories own when it fires; the extension consumes `DomainModels` read-only.
  Repo `*Live` targets may depend on client INTERFACES (LogClient precedent in BriefRepositoryLive).
- `BriefRepository` is installed `routed(dev:)` — in mock mode the live policies never run, so the widget
  snapshot is only written on live-path generates (acceptable; mock mode is a DEBUG dev tool).
- Existing `BriefRepositoryLiveTests` run with `TestDependencyKey` defaults — a new `@Dependency` in
  `dailyBriefPolicy` MUST have a no-op `testValue` or every existing test breaks.
- swift-dependencies resolves `liveValue` via dynamic conformance lookup: a module that only imports the
  interface can `@Dependency(\.widgetSnapshot)` and still get the live value at runtime, provided the
  *process* (app or extension) links the `*Live` module. This is how the extension's timeline provider
  reads the store without WidgetsUI importing the Live target.
- SwiftLint: `included: [Sources]` — the new `CoachWidgets/` extension folder (repo root, beside `App/`)
  is outside lint scope, same as `App/`. `nesting` (type level 1) is enforced → snapshot sub-structs must
  be top-level types, not nested in `WidgetSnapshot`.
- Snapshot-test file naming: keep `test_` prefixes (PNG paths derive from them); never swiftformat test files.
- Tests are Swift Testing (`import Testing`) with explicit `import Foundation` where needed.

## Constraints

- `project.pbxproj`'s `DEVELOPMENT_TEAM = GR9SJM3FZP` must survive in every configuration touched or added
  (both CoachApp configs AND both new CoachWidgets configs).
- The extension must NOT link Database/GRDB or APIClient — verified by its
  `packageProductDependencies` list (epic acceptance criterion).
- `make test-snapshots` / `record-snapshots` / any sim TEST run is a serialized shared resource —
  compile-only `xcodebuild build` with a sim destination is the allowed gate in this worktree.
- The snapshot write must never fail or delay the brief path — fire-and-forget, non-throwing.
- No accessibility/VoiceOver code (standing owner rule).
- No computed `some View` properties — inline or extract a struct view.

## Useful Commands

```bash
swift build                      # host compile gate
swift test                       # full package unit suite (must stay 100% green)
make lint                        # swiftlint --strict
xcodebuild -project CoachApp.xcodeproj -scheme CoachApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' build   # compile-only app+extension gate
```

## Uncertainty

- WidgetKit compiles for the macOS 14 host (`swift build`) — believed yes (WidgetKit is macOS 11+), but
  every WidgetKit-importing file is `#if canImport(WidgetKit)`-guarded anyway so a host without the module
  degrades to an empty file instead of breaking `swift test`. Resolved by guard-always.
- App Group provisioning on a real device (automatic signing must register
  `group.com.smeshko.CoachApp` with team GR9SJM3FZP) — cannot be verified from this environment;
  simulator builds skip provisioning. Flagged as owner-side validation in the final task.
- Widget gallery/timeline behaviour is only observable via `verify-on-sim` (epic Validation) — deferred to
  implementation-time evidence, not plannable further here.

## References

- `docs/artifacts/epics/21-widgets.md` — the epic; 21.1 `### What to build` + acceptance criteria.
- Orchestrator scope additions (recorded in PLAN.md Scope): full schema now, staleness helper, URL-scheme
  deep links, WidgetsUI module + snapshot target, pbxproj extension target, writer hook — all deliberate
  21.1 widening so 21.2–21.5 can be implemented in parallel with zero Package.swift/Makefile/pbxproj conflicts.
