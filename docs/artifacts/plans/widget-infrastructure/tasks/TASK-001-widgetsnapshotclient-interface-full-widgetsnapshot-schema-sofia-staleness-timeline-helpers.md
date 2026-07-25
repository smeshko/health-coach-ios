# TASK-001: WidgetSnapshotClient interface: full WidgetSnapshot schema + Sofia staleness/timeline helpers

Depends on: None
Suggested commit: `feat(widgets): WidgetSnapshotClient interface — full snapshot schema + Sofia staleness helpers`

## Goal

Create the `WidgetSnapshotClient` interface module carrying the COMPLETE `WidgetSnapshot` Codable schema
(daily core + optional weekly + optional check-in sections — later phases never touch it again), the
Sofia timeline/staleness helpers, and the closure-struct dependency with a no-op `testValue`.

## Files

- `Sources/Clients/WidgetSnapshot/Interface/WidgetSnapshot.swift` — new: the schema (top-level types, per
  SwiftLint `nesting` level-1):
  - `WidgetSnapshot`: `schemaVersion: Int` (`static let currentSchemaVersion = 1`),
    `generatedAt: Date`, `daily: WidgetDailySnapshot?`, `weekly: WidgetWeeklySnapshot?`,
    `checkIn: WidgetCheckInState?`. `Codable + Equatable + Sendable`, memberwise `public init` with
    defaulted optionals (house style: DomainModels/DailyBrief.swift).
  - `WidgetDailySnapshot`: `date: Date` (the brief's Sofia day), `readiness: Readiness`,
    `safetyGate: SafetyGate`, `plannedSession: SessionBlock`, `selectedSession: SessionBlock?` (nil until
    21.2 writes it — "selected-vs-planned" is `selectedSession ?? plannedSession` at render),
    `macroFocus: MacroFocus`, `intakeYesterday: IntakeSummary?`.
  - `WidgetWeeklySnapshot`: `isoWeek: String` (canonical `"%04d-W%02d"`), `budgets: WeeklyBudgets`
    (carries `deload`), `targets: WeeklyTargets`, `coreSessions: [PlannedSession]` (has `suggestedDay`).
  - `WidgetCheckInState`: `date: Date` (Sofia day it refers to), `logged: Bool`,
    `source: WidgetCheckInSource?` (`enum WidgetCheckInSource: String, Codable, Equatable, Sendable
    { case app, widget }`; nil while unlogged).
  - All DomainModels types are embedded directly (DECISIONS D2) — no mirror structs.
- `Sources/Clients/WidgetSnapshot/Interface/WidgetSnapshotCoding.swift` — new: `enum WidgetSnapshotCoding`
  with `static func makeEncoder() -> JSONEncoder` / `static func makeDecoder() -> JSONDecoder` pinning
  `.iso8601` date strategies — the ONE wire format store, tests, and extension share.
- `Sources/Clients/WidgetSnapshot/Interface/WidgetTimeline.swift` — new: the shared staleness/timeline
  helpers (DECISIONS D3), all taking `calendar: Calendar = .europeSofia` explicitly (the extension process
  has no `prepareDependencies`, so `@Dependency(\.calendar)`/`ISOWeek.current` are off-limits here):
  - `WidgetTimeline.nextSofiaMidnight(after date: Date, calendar: Calendar = .europeSofia) -> Date` —
    start of the NEXT Sofia day (the timeline-entry refresh date for every later widget).
  - `WidgetDailySnapshot.isCurrent(at now: Date, calendar: Calendar = .europeSofia) -> Bool` — same
    Sofia calendar day as `now` (mirrors `sofiaToday()`'s `startOfDay` key, SyncGate.swift:12).
  - `WidgetWeeklySnapshot.isCurrent(at now: Date, calendar: Calendar = .europeSofia) -> Bool` — formats
    `now`'s ISO week with the same `"%04d-W%02d"` pattern as `BriefRepositoryLive.isoWeekKey`
    (WeeklyPlanPolicy.swift:17-19 — module-internal there, so the 3-line formatter is duplicated here
    with a cross-reference comment) and compares to `isoWeek`.
- `Sources/Clients/WidgetSnapshot/Interface/WidgetSnapshotClient.swift` — new: the dependency
  (LogClient.swift is the template):
  - `public struct WidgetSnapshotClient: Sendable` with
    `updateDailyBrief: @Sendable (DomainModels.DailyBrief) async -> Void` (non-throwing —
    fire-and-forget by contract, DECISIONS D6) and `read: @Sendable () async -> WidgetSnapshot?`.
    `public init` takes both closures (later phases ADD defaulted closure params — additive).
  - `extension WidgetSnapshotClient: TestDependencyKey` — `testValue`/`previewValue` = no-op update +
    nil read (keeps every existing BriefRepositoryLiveTests green once TASK-005 lands).
  - `public extension DependencyValues { var widgetSnapshot: WidgetSnapshotClient }` accessor.
- `Sources/Clients/WidgetSnapshot/Tests/WidgetSnapshotClientTests/WidgetSnapshotSchemaTests.swift` — new
  (host, Swift Testing; nested-dir layout because a second test target arrives in TASK-002 — the
  LogClient `Tests/LogClientTests` precedent).
- `Package.swift` — new targets `WidgetSnapshotClient` (deps: CoachCore, DomainModels,
  `.product(name: "Dependencies", ...)`; path `Sources/Clients/WidgetSnapshot/Interface`) and
  `WidgetSnapshotClientTests` (deps: WidgetSnapshotClient, DomainModels, SampleData, CoachCore; path
  `Sources/Clients/WidgetSnapshot/Tests/WidgetSnapshotClientTests`); new
  `.library(name: "WidgetSnapshotClient", ...)` product (the extension target links it in TASK-006);
  both targets with the standard `.swiftLanguageMode(.v6)` setting and a house-style dependency comment.

## Acceptance

- [ ] `WidgetSnapshot` round-trips through `WidgetSnapshotCoding` with all three sections populated and
      with only `daily` populated (`weekly`/`checkIn` nil, decoded back as nil).
- [ ] A pinned JSON literal (daily-only, schemaVersion 1) decodes — the frozen wire shape later phases rely on.
- [ ] `nextSofiaMidnight` returns the next Sofia-day start (incl. across a month boundary and for a
      `now` exactly at midnight → the FOLLOWING midnight).
- [ ] Daily `isCurrent`: true same Sofia day, false for yesterday's snapshot just past midnight; boundary
      exercised with fixed instants where the UTC day ≠ Sofia day (Sofia is UTC+2/+3).
- [ ] Weekly `isCurrent`: true for `now` in the same ISO week, false after rollover; the year-boundary
      case covered (e.g. 2025-12-29 belongs to `2026-W01`, per the ISOWeek doc comment).
- [ ] `swift build`, `swift test`, `make lint` all green.

Evidence: `swift test` output listing the new `WidgetSnapshotClientTests` suite green.

## Steps

### RED
- [ ] Add `WidgetSnapshotSchemaTests.swift` (`import Testing`, `import Foundation`, `test_` prefixes):
      round-trip full/daily-only, pinned-JSON decode, `nextSofiaMidnight` cases, daily/weekly `isCurrent`
      cases with explicit `Calendar.europeSofia` and fixed `Date(timeIntervalSince1970:)` instants.
- [ ] Register both targets + the product in Package.swift so the tests compile (and fail against the
      missing implementation first).

### GREEN
- [ ] Implement the four interface files exactly as specified in Files.

### REFACTOR
- [ ] Doc-comments in house style (sparse, decision-referencing); confirm no `@Dependency` snuck into the
      helpers; `make lint`.

## Notes

- Keep every schema property `public var` (house style) and every type `Equatable` — later phases compare
  them in snapshot fixtures and TCA state.
- Do NOT add a pending-`CheckIn` payload to `WidgetCheckInState` — 21.5's inbox file owns pending
  check-ins; this section is display state only.
- Never run swiftformat on the test file (repo rule).
