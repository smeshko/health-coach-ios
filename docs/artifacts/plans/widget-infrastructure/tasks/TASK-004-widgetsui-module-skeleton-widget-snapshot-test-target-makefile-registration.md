# TASK-004: WidgetsUI module: skeleton widget, snapshot-test target, Makefile registration

Depends on: TASK-001,TASK-002
Suggested commit: `feat(widgets): WidgetsUI module — skeleton widget + snapshot-test target`

## Goal

Create the `Sources/Features/WidgetsUI` package module owning ALL widget implementation (views,
providers, `Widget` conformances — the extension will hold only the `@main` bundle, DECISIONS D4), seeded
with the skeleton widget, plus its registered snapshot-test target and the Makefile `SNAPSHOT_TARGETS`
entry — so 21.2–21.5 add only Swift files here.

## Files

- `Sources/Features/WidgetsUI/Sources/SkeletonWidget.swift` — new, whole file
  `#if canImport(WidgetKit)`-guarded (host-build safety, RESEARCH Uncertainty):
  - `SkeletonEntry: TimelineEntry` — `date: Date`, `snapshot: WidgetSnapshot?`.
  - `SkeletonProvider: TimelineProvider` — `@Dependency(\.widgetSnapshot)` read (the interface; the
    extension process links Live so the dynamic `liveValue` lookup resolves the real store — RESEARCH
    Architecture Facts); `getTimeline` emits one entry at `date.now`-equivalent (`Date()` — no ambient
    dependency in the extension) with `policy: .after(WidgetTimeline.nextSofiaMidnight(after: now))`;
    `placeholder`/`getSnapshot` return a fixture entry.
  - `public struct SkeletonWidget: Widget` — `StaticConfiguration(kind: "CoachSkeletonWidget",
    provider:)` rendering `SkeletonWidgetView`, `.supportedFamilies([.systemSmall])`,
    `.containerBackgroundRemovable()` default left alone; `public init()`.
- `Sources/Features/WidgetsUI/Sources/SkeletonWidgetView.swift` — new, NOT WidgetKit-guarded (plain
  SwiftUI so the snapshot target renders it): takes `date: Date?` + `readinessScore: Int?` + `isStale:
  Bool` (or an equivalent small display-value struct — derived from `WidgetDailySnapshot` by the caller);
  renders the snapshot date (formatted) + readiness score, and a placeholder line when nil/stale.
  Placeholder visuals only (epic: "just proof the pipeline flows"); use basic `DesignSystem` tokens for
  colors/type. `widgetURL(CoachDeepLink.today.url)` applied in the WidgetKit-side wrapper (guarded file),
  not here. NO computed `some View` decomposition; no a11y modifiers (standing rules).
- `Sources/Features/WidgetsUI/Tests/WidgetsUISnapshotTests/SkeletonWidgetViewSnapshotTests.swift` — new,
  `#if canImport(UIKit)`-guarded (SnapshotConvention precedent): one populated state + one stale state,
  each wrapped in a fixed small-widget-ish frame (e.g. `.frame(width: 170, height: 170)` on a
  `.coachBackground`) through `assertCoachSnapshot` (light+dark). Swift Testing, `test_` prefixes —
  PNG paths derive from them.
- `Package.swift` — new target `WidgetsUI` (path `Sources/Features/WidgetsUI/Sources`; deps:
  WidgetSnapshotClient, DomainModels, DesignSystem, CoachCore, `.product(Dependencies)` — DesignSystem
  now so 21.2's styled widgets need no Package.swift edit, DECISIONS D4) + `.library(name: "WidgetsUI")`
  product; new test target `WidgetsUISnapshotTests` (path
  `Sources/Features/WidgetsUI/Tests/WidgetsUISnapshotTests`; deps: WidgetsUI, WidgetSnapshotClient,
  DomainModels, SampleData, CoachTestSupport, DesignSystem, CoachCore,
  `.product(SnapshotTesting)`; `exclude: ["__Snapshots__"]`).
- `Makefile` — edit line 9: append `-only-testing:WidgetsUISnapshotTests` to `SNAPSHOT_TARGETS`.

## Acceptance

- [ ] `swift build` + `swift test` green on the host (WidgetKit-guarded files compile or vanish cleanly;
      the UIKit-guarded snapshot target compiles to an empty module).
- [ ] `make lint` green.
- [ ] `SNAPSHOT_TARGETS` lists `WidgetsUISnapshotTests`.
- [ ] Reference PNGs for the two snapshot tests recorded on the pinned canonical sim and committed
      (SIM-SERIALIZED STEP — see Notes).

Evidence: `swift test` output; the committed `__Snapshots__` PNGs; `git diff Makefile`.

## Steps

### RED
- [ ] Add the snapshot test file + register both targets and the Makefile entry (test fails: no view).

### GREEN
- [ ] Implement `SkeletonWidgetView`, then the guarded `SkeletonWidget`/provider/entry file.

### REFACTOR
- [ ] Verify module deps carry NO Database/GRDB/APIClient edge (`swift package show-dependencies` or
      Package.swift review); house-style comments.

## Snapshot recording (sim-serialized)

The pinned iPhone 17 Pro / OS 26.0 sim is a serialized shared resource. Recording the two new PNGs
(`make record-snapshots`, or a targeted
`TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild test … -only-testing:WidgetsUISnapshotTests`) must be
coordinated with the orchestrator/owner — do NOT run it concurrently with other worktrees' sim jobs. If
the slot isn't available when this task is implemented, commit the code, leave this checkbox open, and
record before TASK-007.

## Notes

- Keep provider logic thin: staleness display = `snapshot?.daily?.isCurrent(at: now) != true` — the
  TASK-001 helper, not re-derived date math.
- The snapshot tests snapshot the plain VIEW (not the WidgetKit configuration) — WidgetKit previews
  aren't renderable by swift-snapshot-testing, and the view is what later phases iterate on.
- Kind string `"CoachSkeletonWidget"` is throwaway (the skeleton is replaced by 21.2+); real widgets pick
  their own kinds.
