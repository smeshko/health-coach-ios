# Plan: Widget infrastructure — App Group, CoachWidgets extension, snapshot pipeline

Status: in-progress
Branch: feat/phase-21-1-widget-infrastructure
Risk: high
Epic: 21 — Home-screen widgets ([epic](../../epics/21-widgets.md))
Phase: 21.1 — Widget infrastructure — App Group, extension target, snapshot pipeline
Linear: none
Created: 2026-07-24

## Goal

Stand up the complete widget substrate — App Group + `CoachWidgets` extension target, the FULL
`WidgetSnapshot` schema, the atomic App-Group JSON pipeline written from `BriefRepositoryLive`, Sofia
staleness/timeline helpers, `coachapp://` deep-link routing, and a registered WidgetsUI module with its
snapshot-test target — proven end-to-end by a skeleton widget rendering the snapshot's date + readiness
score, so phases 21.2–21.5 can each be implemented in parallel by adding only Swift files.

## Scope

The epic's 21.1 spec, PLUS six deliberate scope additions (orchestrator decision — they unlock parallel
implementation of 21.2–21.5 with zero Package.swift/Makefile/pbxproj merge conflicts later):

1. **Full `WidgetSnapshot` Codable schema NOW** — daily core (snapshot date, `generatedAt`, readiness
   score/band + safety-gate state, today's `SessionBlock` incl. selected-vs-planned, `MacroFocus`,
   `intakeYesterday`) PLUS optional weekly section (`isoWeek`, `WeeklyBudgets`, key `WeeklyTargets`,
   core-session summaries with suggested days, deload via `WeeklyBudgets.deload`) PLUS optional
   today-check-in state (logged/unlogged + source). Later phases add writers and UI, never schema surgery.
2. **Shared timeline/staleness helpers** — next-Europe/Sofia-midnight entry dating + "stale for the
   current Sofia day / current ISO week" checks, host-unit-tested.
3. **URL-scheme deep links** — `coachapp` scheme registered; `CoachDeepLink` vocabulary in CoachCore;
   AppFeature reducer routes `coachapp://today`, `coachapp://weekly`, `coachapp://checkin`, reducer-tested.
4. **`Sources/Features/WidgetsUI` package module** with its own `WidgetsUISnapshotTests` target,
   registered in Package.swift AND appended to the Makefile's `SNAPSHOT_TARGETS`, seeded with the
   skeleton widget + one snapshot test.
5. **`CoachWidgets` WidgetKit extension target** hand-authored in `project.pbxproj` (CA-id style),
   entitlements with shared App Group `group.com.smeshko.CoachApp` for app + extension, embedded in the
   app; extension links ONLY DomainModels + the snapshot modules + WidgetsUI. The `@main` `WidgetBundle`
   lives in the extension and lists widgets from WidgetsUI.
6. **Snapshot writer** (`WidgetSnapshotClient` interface + `WidgetSnapshotClientLive`) hooked into
   `BriefRepositoryLive`'s daily-brief cache path with `WidgetCenter.reloadAllTimelines()` after each
   write; atomic JSON write/read against the App Group container.

## Out of Scope

- The four real widgets (session / macros / weekly / check-in nudge) — phases 21.2–21.5. The skeleton
  widget is pipeline proof only and will be replaced.
- Writers for the weekly (21.4), session-selection (21.2), and check-in (21.5) snapshot sections — the
  schema and merge semantics land here; the write hooks belong to their phases.
- The App-Group check-in **inbox** file + AppIntent (21.5).
- Weekly used-vs-budget progress, sqlite-in-App-Group, readiness ring widgets, watchOS/Live
  Activities/StandBy, accessibility work — all epic-level exclusions.
- Any `SNAPSHOT_TESTING` sim TEST run outside the recording step flagged in TASK-004 (serialized resource).

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing facts: `dailyBriefPolicy` is the single daily cache write
to hook (`cachedDailyBriefPolicy` is a pure peek); all schema constituents in DomainModels are already
`Codable + Equatable + Sendable`; LogClient is the interface/live split to mirror (incl. the nested
two-test-target layout); `notificationOpened` is the reducer routing precedent for deep links;
`isoWeekKey` fixes the `"%04d-W%02d"` week-string format; the pbxproj is single-target, hand-authored
CA-ids with `DEVELOPMENT_TEAM = GR9SJM3FZP` to preserve; new targets must compile for the macOS host, so
WidgetKit imports are always `#if canImport(WidgetKit)`-guarded.

## Decisions

All in [DECISIONS.md](./DECISIONS.md): D1 module naming (`WidgetSnapshotClient`/`-Live`), D2 schema
embeds DomainModels types in optional top-level sections, D3 staleness helpers in the interface module
with explicit `Calendar`, D4 all widget code in WidgetsUI (extension holds only the `@main` bundle),
D5 `CoachDeepLink` in CoachCore + check-in routes to the Today tab's gate, D6 merge-write fire-and-forget
writer on the generate path only, D7 hand-authored appex target conventions + App Group id.

## Risks

- **pbxproj hand-edit breaks the project file** — mitigated by the compile-only sim-destination
  `xcodebuild build` gate in TASK-005/TASK-006 and by copying the existing object shapes exactly
  (RESEARCH.md documents the free id ranges and required settings, incl. `DEVELOPMENT_TEAM`).
- **WidgetKit availability on the macOS host build** — all WidgetKit-importing files
  `#if canImport(WidgetKit)`-guarded; host `swift build`/`swift test` stay green either way.
- **Lost update on concurrent read-modify-write of the snapshot file** — the store's read→merge→write is
  not atomic, and 21.1 freezes the merge design for later phases whose sibling section writers
  (weekly/selected/check-in) all mutate the same file; two interleaved writes drop a section. Mitigated by
  serializing the live client's writes through a single actor (TASK-002 Notes / validation round-1 #3) so
  concurrent `update*` calls cannot lose each other's sections; the pure merge stays a free function.
- **New `@Dependency` breaks existing BriefRepositoryLiveTests** — `WidgetSnapshotClient` ships a no-op
  `testValue`, so unoverridden tests keep passing; the new behaviour is asserted with an explicit
  recording override.
- **App Group provisioning on device** (automatic signing must register the group) — unverifiable from
  this environment; sim builds skip provisioning. Owner-side device validation, flagged in TASK-007.
- **Snapshot PNG recording needs the pinned sim** (serialized shared resource) — TASK-004 lands the test
  code; the one recording run is called out explicitly and must be coordinated, not run ad hoc.
- **Widget gallery behaviour on sim** (adding the widget, timeline reload visibility) — only observable
  via `verify-on-sim` at implementation time; the epic's Validation section owns that evidence.

## Acceptance Criteria

From the epic phase, plus the scope additions:

- [ ] App and extension both build for the canonical sim; `swift build`, `swift test`, `make lint` all green.
- [ ] Refreshing the Today tab (live route) writes/updates the snapshot JSON in the App Group container,
      observable via a log line; `WidgetCenter.reloadAllTimelines()` fires after each write.
- [ ] The skeleton widget shows the snapshot's readiness score and date, and updates after an in-app
      refresh (verify-on-sim evidence at implementation time).
- [ ] The extension's `packageProductDependencies` list contains ONLY WidgetsUI,
      WidgetSnapshotClientLive, and DomainModels — no Database/GRDB, no APIClient.
- [ ] `WidgetSnapshot` carries the FULL schema (daily + optional weekly + optional check-in sections);
      encode/decode and merge-preservation are unit-tested on the host.
- [ ] Staleness/timeline helpers (next Sofia midnight, same-Sofia-day, same-ISO-week) are host-unit-tested.
- [ ] `coachapp://today`, `coachapp://weekly`, `coachapp://checkin` route correctly at the reducer level
      (tab switches, onboarding guard, unknown-URL no-op), unit-tested.
- [ ] `WidgetsUISnapshotTests` exists, is listed in the Makefile's `SNAPSHOT_TARGETS`, and contains the
      skeleton widget snapshot test.
- [ ] `DEVELOPMENT_TEAM = GR9SJM3FZP` present in all four target configurations (2× CoachApp, 2× CoachWidgets).

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: WidgetSnapshotClient interface: full WidgetSnapshot schema + Sofia staleness/timeline helpers
- [x] TASK-002: WidgetSnapshotClientLive: atomic App-Group JSON store + WidgetCenter reload (depends on TASK-001)
- [x] TASK-003: URL-scheme deep links: coachapp:// routes into AppFeature (Today / Weekly / check-in)
- [x] TASK-004: WidgetsUI module: skeleton widget, snapshot-test target, Makefile registration (depends on TASK-001,TASK-002)
- [x] TASK-005: Snapshot writer hook in BriefRepositoryLive + composition-root install (depends on TASK-001,TASK-002)
- [x] TASK-006: CoachWidgets extension target: pbxproj, App Group entitlements, embed (depends on TASK-004,TASK-005)
- [ ] TASK-007: Final Validation
