# Decisions: widget-infrastructure

Options actually weighed; the plan follows these without restating.

## D1 — Module naming: `WidgetSnapshotClient` / `WidgetSnapshotClientLive` (not `WidgetSnapshot`)

- **Option A: target named `WidgetSnapshot`** (the epic's literal suggestion). Rejected: the module would
  share its name with its central type (`WidgetSnapshot.WidgetSnapshot`), a known Swift annoyance that
  forces qualification in exactly the places the type is used most.
- **Option B (chosen): path `Sources/Clients/WidgetSnapshot/{Interface,Live}` with targets
  `WidgetSnapshotClient` + `WidgetSnapshotClientLive`.** Matches the epic's directory suggestion and the
  LogClient/APIClient interface–live precedent; the `Client` suffix matches every other closure-struct
  client dependency (`LogClient`, `TokenClient`, `HealthKitClient`, `NotificationClient`).

## D2 — Schema embeds DomainModels types directly; optional top-level sections

- **Option A: mirror structs** (a private wire format for the widget file). Rejected: pure duplication —
  `SessionBlock`, `MacroFocus`, `IntakeSummary`, `Readiness`, `SafetyGate`, `WeeklyBudgets`,
  `WeeklyTargets`, `PlannedSession` are all already `Codable + Equatable + Sendable`, and the extension
  already consumes `DomainModels` read-only by design (epic Architecture references). Mirrors would need
  their own mapping tests and drift maintenance.
- **Option B (chosen): embed the DomainModels types** inside three optional top-level sections —
  `daily: WidgetDailySnapshot?`, `weekly: WidgetWeeklySnapshot?`, `checkIn: WidgetCheckInState?` — plus
  `schemaVersion: Int` and `generatedAt: Date` at the root. Optional sections mean 21.4/21.5 writers merge
  their section in without touching the others, and decode of an old file simply yields `nil` sections
  (no migration). Sub-structs are TOP-LEVEL types (SwiftLint `nesting` level-1 rule).
- The full schema (weekly + check-in fields included) lands NOW by orchestrator decision, so later phases
  add only writers and UI — never schema surgery. `selectedSession: SessionBlock?` sits beside
  `plannedSession` from day one (21.2 fills it; skeleton ignores it).
- Deload: carried by the embedded `WeeklyBudgets.deload` — no duplicate top-level flag.
- Dates: one `WidgetSnapshotCoding` factory (ISO-8601 encoder/decoder) shared by store + tests so both
  processes and all tests agree on one wire format.

## D3 — Staleness/timeline helpers live in the interface module, take explicit `Calendar`

- **Option A: helpers in WidgetsUI** ("in the widgets code" literally). Rejected: WidgetsUI's test target
  is the sim-only snapshot target; date math must be host-tested via `swift test`.
- **Option B (chosen): helpers in `WidgetSnapshotClient`** (`WidgetTimeline.nextSofiaMidnight(after:calendar:)`,
  `WidgetDailySnapshot.isCurrent(at:calendar:)`, `WidgetWeeklySnapshot.isCurrent(at:calendar:)`), defaulting
  `calendar: Calendar = .europeSofia`. The snapshot module IS widgets code (the extension links it), and the
  helpers sit next to the schema they interrogate. Explicit `Calendar` parameter instead of
  `@Dependency(\.calendar)`/`ISOWeek.current` because the extension process never runs
  `prepareDependencies` — the ambient dependency would silently be the device calendar, not Europe/Sofia.
- Week comparison formats the current week with the same `"%04d-W%02d"` pattern `BriefRepositoryLive.isoWeekKey`
  uses and compares strings — the 3-line formatter is duplicated (module-internal there) with a
  cross-reference comment rather than promoted to CoachCore mid-phase.

## D4 — ALL widget implementation (views + providers + `Widget` conformances) in the WidgetsUI package module; the extension target holds ONLY the `@main` bundle

- **Option A: providers/widgets in the extension target, views in the package.** Rejected: every later
  phase would add files to the extension target = a `project.pbxproj` edit per phase — exactly the
  parallel-implementation conflict this phase exists to eliminate.
- **Option B (chosen): `Sources/Features/WidgetsUI` owns everything** (skeleton entry view, timeline
  provider, `SkeletonWidget: Widget`); the extension's single `CoachWidgetsBundle.swift` lists widgets.
  Later phases add Swift files to WidgetsUI + one line to the bundle file — zero
  Package.swift/Makefile/pbxproj edits (Package/Makefile registration happens once, here).
- The provider reads via `@Dependency(\.widgetSnapshot)` against the INTERFACE; the extension process
  links `WidgetSnapshotClientLive`, so swift-dependencies' dynamic `liveValue` lookup resolves the real
  store at runtime (same pattern as the app: features import interfaces, the root links `*Live`).
- WidgetsUI depends on `DesignSystem` from day one (21.2's "visuals consistent with DesignSystem" would
  otherwise force a Package.swift edit later). Its transitive interface deps (CoachCore, DomainModels,
  HealthKitClient-interface→WireModels) are pure value code — the forbidden deps (Database/GRDB,
  APIClient) stay out.

## D5 — Deep-link vocabulary in CoachCore; AppFeature routes; check-in route lands on Today

- **Option A: URL parsing inline in AppFeature only.** Rejected: later phases' widgets need the same URLs
  for `widgetURL`, and WidgetsUI cannot import AppFeature — the string literals would be duplicated
  contract-free across modules.
- **Option B (chosen): `CoachDeepLink` enum in CoachCore** (`case today, weekly, checkIn`) owning the
  `coachapp` scheme constant, the canonical `url` per case (`coachapp://today`, `coachapp://weekly`,
  `coachapp://checkin`), and the `init?(url:)` parser. CoachCore is bottom-of-graph: AppFeature (already a
  dependent) parses with it; WidgetsUI (dependent via DesignSystem→CoachCore) uses `.url` in `widgetURL`.
  Parser is host-tested in CoachCoreTests; routing is reducer-tested in AppFeatureTests.
- Routing: `.today`/`.weekly` set `MainTabs.selectedTab`; `.checkIn` ALSO lands on `.today` — the check-in
  flow IS the Today tab's `checkInRequired` gate (BriefViewState), so an unlogged day surfaces the
  check-in card by itself. The distinct route case exists so 21.5 can specialise behaviour without a new
  URL contract. Guards mirror `notificationOpened`: only-from-`.main`, dropped while onboarding.
- Scheme registration via `CFBundleURLTypes` in the hand-authored `App/Info.plist` (merged by
  `GENERATE_INFOPLIST_FILE = YES`, the existing `UILaunchScreen`/`APIBaseURL` mechanism).

## D6 — Writer semantics: merge-write, fire-and-forget, on the generate path only

- The client interface exposes `updateDailyBrief: @Sendable (DailyBrief) async -> Void` (non-throwing) +
  `read: @Sendable () async -> WidgetSnapshot?`. Later phases add sibling closures
  (`updateSelectedSession`, `updateWeeklyPlan`, `updateCheckIn`) — additive, defaulted in `init`, no
  breaking change.
- `updateDailyBrief` load-merges: read existing file, replace only the `daily` section (+ root
  `generatedAt`), preserve `weekly`/`checkIn`, write atomically (`Data.write(options: .atomic)`), then
  `WidgetCenter.shared.reloadAllTimelines()` (`#if canImport(WidgetKit)`).
- Hooked ONLY where the daily cache is written (`dailyBriefPolicy`'s save, both first-generate and
  refresh) — `cachedDailyBriefPolicy` is a read-only peek and stays untouched. A cache-hit serve doesn't
  rewrite (the snapshot was mirrored when that cache row was written). All failures (no App Group
  container, encode/write errors) log via `LogClient` and drop — the brief path must never fail because a
  widget mirror couldn't be written.
- Weekly-plan-path hook is deliberately NOT added here — 21.4's spec owns it (this phase only guarantees
  the schema + merge semantics it will need).

## D7 — pbxproj: hand-authored appex target in the existing CA-id style

- New object IDs use the free `CA00000000000000000002xx` suffix range (documented in RESEARCH.md).
- `CoachWidgets` = `com.apple.product-type.app-extension` with `NSExtension` →
  `NSExtensionPointIdentifier = com.apple.widgetkit-extension` in a hand `CoachWidgets/Info.plist`
  (merged with `GENERATE_INFOPLIST_FILE = YES`, mirroring the app target's pattern).
- Embedded via a new `PBXCopyFilesBuildPhase` ("Embed Foundation Extensions", `dstSubfolderSpec = 13`,
  `RemoveHeadersOnCopy`) + `PBXTargetDependency`/`PBXContainerItemProxy` on CoachApp.
- Extension `packageProductDependencies`: `WidgetsUI`, `WidgetSnapshotClientLive`, `DomainModels` — and
  nothing else (the no-GRDB/no-APIClient criterion is checked against this exact list). New `.library`
  products are added for these as they appear.
- Both new configurations carry `DEVELOPMENT_TEAM = GR9SJM3FZP`, `CODE_SIGN_STYLE = Automatic`,
  `CODE_SIGN_ENTITLEMENTS = CoachWidgets/CoachWidgets.entitlements`, `SKIP_INSTALL = YES`,
  `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 6.0`; the app's two configs are edited only to
  add the embed phase/dependency — their `DEVELOPMENT_TEAM` lines are untouched.
- App Group id: `group.com.smeshko.CoachApp` (derived from the app bundle id), added to
  `App/CoachApp.entitlements` and `CoachWidgets/CoachWidgets.entitlements`.
