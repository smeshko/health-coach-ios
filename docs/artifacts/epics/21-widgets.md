# Epic 21 — Home-screen widgets

Status: in-progress
Created: 2026-07-24
Depends on: Epic 08, Epic 09
Project: none
Linear: none
Milestone: none

## Overview

Put the coach on the home and lock screen: a WidgetKit extension with four
widget kinds — today's session (with lock-screen accessories), daily macros,
a plan-only weekly overview, and an interactive check-in nudge. The extension
never touches the network or GRDB: the app mirrors a small Codable
`WidgetSnapshot` JSON into an App Group container whenever it caches a daily
brief, weekly plan, session selection, or check-in, and the widgets decode that
one file. Phase 21.1 builds this pipeline; each later phase ships one widget on
top of it.

## Architecture references

- [docs/architecture/ARCHITECTURE.md](../../architecture/ARCHITECTURE.md) —
  layer ownership: the snapshot writer is a client (`Sources/Clients/`), the
  repositories own when it fires, and the extension consumes `DomainModels`
  read-only. The widget extension is a new leaf consumer, not a new layer.

## Dependencies

- **Epic 08** (Done) — the cached daily brief (`DailyBriefRecord`,
  `BriefRepository.cachedDailyBrief`) is the data source for 21.2/21.3.
- **Epic 09** (Done) — the cached weekly plan (`WeeklyPlanRecord`) is the data
  source for 21.4.

## Out of scope

- **Used-vs-budget progress in the weekly widget** — the app never records
  session completion; truthful actuals would need backend-computed progress
  from synced workouts. Deliberately deferred; the weekly widget is plan-only.
- **Moving `coachapp.sqlite` into the App Group** — the JSON snapshot mirror
  was chosen instead; the extension must not link GRDB/Database.
- **Readiness ring / readiness+session combo widgets** — not selected by the
  owner; a later epic can add them on the same snapshot (readiness fields are
  already carried for the session widget's gate state).
- **watchOS complications, Live Activities, StandBy layouts** — home/lock
  screen only.
- **Accessibility/VoiceOver work** — per standing project rule (personal app).

## Phase 21.1 — Widget infrastructure — App Group, extension target, snapshot pipeline

**Plan**: [widget-infrastructure](../plans/widget-infrastructure/PLAN.md) · status: done

**Linear**: none

**Goal**: Stand up the WidgetKit extension with an App Group and a JSON snapshot the app writes on every brief/plan cache, proven by a skeleton widget.

### What to build

- New WidgetKit extension target (e.g. `CoachWidgets`) in `CoachApp.xcodeproj`
  with its own entitlements file. Add an App Group id to both it and
  `App/CoachApp.entitlements`. **Caution:** `project.pbxproj` carries an
  uncommitted hand-made `DEVELOPMENT_TEAM` edit — preserve it.
- New package module `Sources/Clients/WidgetSnapshot/` (interface + live):
  a Codable `WidgetSnapshot` (snapshot date + `generatedAt`, readiness
  score/band + safety gate, today's `SessionBlock` summary, `MacroFocus` +
  `intakeYesterday`) with atomic JSON write/read against the App Group
  container. Leave room to grow (weekly fields land in 21.4, check-in state in
  21.5).
- Hook the snapshot write into `BriefRepositoryLive`'s daily-brief cache path
  and call `WidgetCenter.reloadAllTimelines()` after each write.
- A skeleton widget (any family) rendering the snapshot's date and readiness
  score — placeholder visuals, just proof the pipeline flows.
- The extension links `DomainModels` + `WidgetSnapshot` only — no
  Database/GRDB, no APIClient.

### Acceptance criteria

- [x] App and extension both build and run on the canonical sim; all existing
      tests stay green. Verified: `xcodebuild ... build` succeeded; the
      `CoachWidgets` extension launched cleanly on the sim (log shows the
      extension process starting, its `WidgetBundle` registering
      `CoachSkeletonWidget`, and a placeholder render completing successfully
      for two size classes, no faults/crashes); `swift test` 615/615,
      `make lint` 0 violations, `make test-snapshots` 96/96 (0 ✘, including the
      two new `SkeletonWidgetView` snapshot references).
- [ ] Refreshing the Today tab writes/updates the snapshot JSON in the App
      Group container (observable via log or dev menu). Unit-verified
      (`WidgetSnapshotMirrorTests`, `WidgetSnapshotStoreTests`: the
      `BriefRepositoryLive` generate path calls the mirror, which atomically
      merge-writes the App Group JSON and logs `"Widget snapshot updated"`).
      Live on-device trigger NOT verified this run — the sim's CoachApp
      install requires an owner-provisioned access token (personal-app,
      single static token, no sign-up) unavailable in this environment; the
      App Group container `group.com.smeshko.CoachApp` is confirmed
      provisioned on the sim but held no snapshot file yet. Pending owner
      device validation.
- [ ] The skeleton widget on the sim home screen shows the snapshot's readiness
      score and date, and updates after an in-app refresh. Pending owner
      device validation.
- [x] The widget extension has no GRDB/Database or APIClient dependency
      (verified by its target/package dependency list).

### Validation

Package unit tests for `WidgetSnapshot` encode/decode and writer round-trip;
`verify-on-sim` run with the widget added to the home screen — screenshot
showing live data after an app refresh.

---

## Phase 21.2 — Today's session widget + lock-screen accessories

**Plan**: direct-implemented from epic spec (no formal plan)

**Linear**: none

**Goal**: Ship the home-screen session widget (card, intensity, duration, zone/HR cap, rest state) plus accessoryInline/accessoryRectangular lock-screen families.

### What to build

- `SessionWidget` supporting `systemSmall` + `systemMedium`: card name +
  intensity (e.g. "Threshold · Quality"), duration range, zone target / HR cap
  badge when present. Dedicated rest state for the rest card and for a
  triggered safety gate ("Rest today" + reason), not an empty layout.
- Lock-screen families `accessoryInline` + `accessoryRectangular`: the
  one-line summary ("Easy run · 40–50 min · Z2", or the gate reason).
- Selection-aware snapshot: hook `SessionSelectionRepository.save` into the
  snapshot writer so the widget shows the athlete's *selected* block for the
  day, falling back to the brief's default session.
- Staleness: the timeline provider adds an entry at the next Europe/Sofia
  midnight; past it (no fresh brief) the widget shows a stale/placeholder
  state instead of presenting yesterday's session as current.
- `widgetURL` deep link opening the app on the Today tab (add a URL-scheme
  route in `AppFeature` if none exists yet).
- Visuals consistent with `DesignSystem` tokens within widget constraints.

### Acceptance criteria

- [x] Widget shows today's selected (else planned) session with intensity,
      duration range, and zone/HR cap when the brief has them. Verified:
      `SessionWidgetViewSnapshotTests` (`test_small_session`,
      `test_medium_session`, `test_small_selected`, `test_medium_selected`,
      light+dark) render the selected-vs-planned fallback from a
      `WidgetDailySnapshot` fixture.
- [x] Rest card and triggered safety gate render their dedicated states.
      Verified: `test_small_rest`/`test_medium_rest` and
      `test_small_gate`/`test_medium_gate` cover the gate>rest>session
      precedence with dedicated fixture states.
- [x] Inline + rectangular lock-screen families render the one-line summary.
      Verified: `test_inline_session`, `test_inline_rest`, `test_inline_gate`,
      `test_inline_selected`, `test_inline_stale` and the `rectangular`
      counterparts, light+dark.
- [x] After Sofia midnight with no new brief cached, the widget shows the
      stale state. Verified: `test_small_stale`/`test_medium_stale`/
      `test_inline_stale`/`test_rectangular_stale`, exercising the Sofia
      calendar-day boundary (`WidgetDailySnapshot.isCurrent(at:)` +
      `WidgetTimeline.nextSofiaMidnight`); the extension-only
      `DailyProvider` timeline wiring itself is not host-testable (WidgetKit
      unavailable off-device) — pending owner device validation.
- [x] Tapping any family opens the app on the Today tab. Verified in code:
      `SessionWidget.swift` applies `.widgetURL(CoachDeepLink.today.url)` on
      every family. Live on-device tap-to-open NOT verified this run —
      pending owner device validation.

### Validation

Snapshot tests for the widget views (all families × normal/rest/gate/stale
states) in the package test target; unit test for the midnight timeline-entry
dating; `verify-on-sim` screenshots of home-screen and lock-screen placements.

**Ship gate (2026-07-25):** rebase onto `origin/staging` picked up the
sibling 21.4 weekly-widget PR; additive conflict resolution in
`WidgetSnapshotClient`/`WidgetSnapshotClient+Live`/`WidgetSnapshotStore` +
their tests (kept `updateWeeklyPlan` and `updateSelectedSession` side by
side) and in `CoachWidgetsBundle` (all four widgets registered); `swift
build` clean; `swift test` 629/629; new `SessionWidgetViewSnapshotTests`
references recorded on the pinned sim (40 new PNGs, 20 states ×
light/dark) with pre-existing skeleton/weekly references byte-unchanged;
`make lint` 0 violations in 424 files; `make test-snapshots` 125/125 (0 ✘,
99 baseline + 26 new session/macros-widget tests); `xcodebuild ... CoachApp
... build` succeeded (CoachWidgets extension embeds cleanly, both
`SessionWidget` and `MacrosWidget` link). Adversarial review found no real
bugs (verified selected-vs-planned fallback, gate>rest>session precedence,
Sofia-midnight staleness boundary, and the extension dependency rule). On-sim/
on-device visual placement and live deep-link/staleness behaviour remain
pending owner device validation, per epic convention.

---

## Phase 21.3 — Macros widget

**Plan**: direct-implemented from epic spec (no formal plan)

**Linear**: none

**Goal**: Ship the daily nutrition widget: day type plus kcal/protein/carb targets, with yesterday's intake-vs-target footer.

### What to build

- `MacrosWidget` supporting `systemSmall` + `systemMedium`: `DayType` badge
  (hard/moderate/rest, colored per app convention) + today's `MacroFocus`
  targets — kcal, protein, carbs (medium adds the fat range and hydration).
- Yesterday footer from `intakeYesterday.vsTarget` when present: calories %
  and protein hit ✓/✗; layout collapses cleanly when `intakeYesterday` is nil.
- Same staleness rule and deep link (Today tab) as 21.2 — reuse the shared
  timeline/staleness helper rather than duplicating it.

### Acceptance criteria

- [x] Targets match the cached brief's `MacroFocus` for the day; day-type
      badge follows app colors. Verified: `MacrosWidgetViewSnapshotTests`
      (`test_small_withIntake`, `test_medium_withIntake`,
      `test_small_withoutIntake`, `test_medium_withoutIntake`, light+dark)
      render kcal/protein/carbs (medium adds fat range + hydration) and the
      `DayType` badge colors matching `CarbCyclingPattern`.
- [x] Footer shows calories % and protein ✓/✗ when intake data exists, and is
      absent — without layout gaps — when it doesn't. Verified: the
      `withIntake` vs `withoutIntake` snapshot pairs cover the collapse; the
      footer math (`caloriesPct` fraction → `.percent`) matches the app's
      `YesterdayIntakeView` convention (adversarial review confirmed).
- [x] Stale state after Sofia midnight, matching 21.2 behaviour. Verified:
      `test_small_stale`/`test_medium_stale`, sharing the same
      `DailyProvider`/staleness helper as `SessionWidget` (no duplication).
- [x] Tapping opens the app on the Today tab. Verified in code:
      `MacrosWidget.swift` applies `.widgetURL(CoachDeepLink.today.url)`.
      Live on-device tap-to-open NOT verified this run — pending owner
      device validation.

### Validation

Snapshot tests for small/medium × with/without intake × stale;
`verify-on-sim` screenshot alongside the session widget.

**Ship gate (2026-07-25):** part of the same rebase/gate run as 21.2 (see
its ship-gate note above) — `swift test` 629/629, new
`MacrosWidgetViewSnapshotTests` references recorded on the pinned sim (12
new PNGs, 6 states × light/dark), `make lint` 0 violations, `make
test-snapshots` 125/125 (0 ✘), sim `xcodebuild ... CoachApp ... build`
succeeded. Adversarial review found no real bugs (intake-footer math
verified against `YesterdayIntakeView`, selection writer hook fires after
the DB write on the correct repo path with same-Sofia-day-only merge and
cross-day drop). On-sim/on-device visual placement and live behaviour
remain pending owner device validation, per epic convention.

---

## Phase 21.4 — Weekly overview widget

**Plan**: direct-implemented from epic spec (no formal plan)

**Linear**: none

**Goal**: Ship the plan-only weekly widget: budgets, targets, and remaining core sessions from the cached WeeklyPlan.

### What to build

- Extend `WidgetSnapshot` with weekly fields (`isoWeek`, `WeeklyBudgets`, key
  `WeeklyTargets`, core-session summaries with suggested days) and hook the
  snapshot write into `BriefRepositoryLive`'s weekly-plan cache path.
- `WeeklyWidget` (`systemMedium`): week label, budgets (hard days, strength
  sessions, long-run km when set), key targets (total run km, cadence), and
  the core sessions with their suggested weekdays; extras excluded. Distinct
  visual treatment for a deload week.
- **No progress counting** — the widget states the plan; it never claims
  used-vs-budget (see Out of scope).
- Stale state once the cached plan's `isoWeek` is no longer the current week;
  deep link opens the Weekly tab.

### Acceptance criteria

- [x] Widget shows the current week's budgets, targets, and core sessions from
      the cached `WeeklyPlan`; deload weeks are visually flagged. Verified:
      `WeeklyWidgetViewSnapshotTests` (`test_normal`, `test_deload`) render
      the week label, budgets, targets, and core sessions from a
      `WeeklyPlan` fixture; the deload case shows the distinct warning
      treatment. Recorded/passing snapshot references
      (`WeeklyWidgetViewSnapshotTests/test_normal.*`,
      `test_deload.*`, `test_stale.*`, light+dark).
- [x] No used/completed counts appear anywhere in the widget. Verified by
      code review of `WeeklyWidgetView.swift` (budgets/targets/core sessions
      only, no used-vs-budget rendering) plus the merge semantics in
      `WidgetSnapshotStore` (core sessions only, extras dropped) covered by
      `WeeklyPlanMirrorTests`/`WidgetSnapshotStoreTests`.
      On-sim/on-device visual confirmation pending owner device validation.
- [x] Week rollover without a fresh plan → stale state. Unit-verified: the
      shared ISO-week staleness helper (Sofia `.iso8601` calendar,
      `%04d-W%02d` key matching the server) is exercised by
      `WeeklyWidgetViewSnapshotTests/test_stale` and covered transitively by
      the writer/merge tests. Live rollover-at-midnight behaviour on-device
      NOT verified this run — pending owner device validation.
- [x] Tapping opens the app on the Weekly tab. Verified in code:
      `WeeklyWidget.swift` applies `.widgetURL(CoachDeepLink.weekly.url)`.
      Live on-device tap-to-open NOT verified this run — pending owner
      device validation.

### Validation

Unit test for the weekly snapshot round-trip; snapshot tests (normal/deload/
stale); `verify-on-sim` screenshot with a cached weekly plan.

**Ship gate (2026-07-25):** rebase onto `origin/staging` was a no-op (branch
already sat on top of the merged 21.1 PR, no sibling widget PRs landed yet);
`swift build` clean; `swift test` 624/624; new `WeeklyWidgetViewSnapshotTests`
references recorded on the pinned sim (6 new PNGs, normal/deload/stale ×
light/dark) with pre-existing skeleton-widget references byte-unchanged;
`make lint` 0 violations in 414 files; `make test-snapshots` 99/99 (0 ✘,
96 baseline + 3 new weekly-widget tests); `xcodebuild ... CoachApp ... build`
succeeded (CoachWidgets extension embeds cleanly). Adversarial review found
no real bugs. On-sim/on-device visual placement and live deep-link/staleness
behaviour remain pending owner device validation, per epic convention.

---

## Phase 21.5 — Interactive check-in nudge widget

**Plan**: direct-implemented from epic spec (no formal plan)

**Linear**: none

**Goal**: Ship an interactive widget that quick-logs an all-clear daily check-in via AppIntent and deep-links into the app for symptomatic days.

### What to build

- Extend `WidgetSnapshot` with today's check-in state; write it from
  `CheckInRepository.save` so the widget knows whether today is logged.
- `CheckInWidget` (`systemSmall`): unlogged state shows an "All clear"
  interactive button (AppIntent) plus a "Symptoms…" deep link into the app's
  check-in flow; logged state shows a confirmation instead of the button.
- The AppIntent runs in the extension, which has no DB: it appends a pending
  `CheckIn` (defaults: `giSymptoms=false, kneePain=0, illness=false`) to an
  App Group **inbox** file and flips the snapshot to logged immediately. The
  app drains the inbox on launch/foreground through `CheckInRepository.save`
  — drain is idempotent, latest-wins per Sofia day (matching the existing
  `CheckInRecord` convention), and an in-app check-in for the same day wins
  over a pending all-clear.
- Nudge behaviour: state resets to unlogged at the Sofia-day rollover.

### Acceptance criteria

- [x] Tapping "All clear" flips the widget to logged immediately, without
      opening the app. Verified at the unit level: `logCheckInFromWidget`
      appends to the inbox and flips the snapshot to logged/`.widget` in one
      call (`WidgetCheckInInboxStoreTests`,
      `WidgetSnapshotStoreCheckInMergeTests`); the logged state renders per
      `CheckInWidgetViewSnapshotTests.test_logged`. Live intent tap on a
      device NOT verified — pending owner device validation.
- [x] On next app foreground, today's `CheckIn` exists in the DB with the
      all-clear defaults; draining twice creates no duplicate. Verified:
      `CheckInWidgetDrainTests.test_drain_persistsPendingAllClearWithDefaults`,
      `test_drainTwice_createsOneRecord`,
      `test_drain_withUnclearedInbox_staysIdempotent`.
- [x] A check-in already logged in-app shows the logged state on the widget
      and suppresses the button; the pending inbox entry never overwrites it.
      Verified: `test_drain_sameDay_inAppCheckInWins` +
      `test_save_mirrorsLoggedStateWithAppSource`; the logged snapshot state
      renders without the button (`test_logged`).
- [x] "Symptoms…" deep-links into the app's check-in UI. Verified in code:
      the unlogged state links `CoachDeepLink.checkIn.url` (route landed in
      21.1, reducer-tested). Live tap NOT verified — pending owner device
      validation.
- [x] State resets to unlogged after the Sofia-day rollover. Verified:
      the provider's Sofia-midnight staleness (shared 21.1 helper) +
      `CheckInWidgetViewSnapshotTests.test_stale`; prior-day pending entries
      never stomp a later day (`test_mergeCheckIn_priorDayIncoming_keepsLaterDayState`,
      `test_drain_yesterdaysPending_persistsUnderItsOwnDay`). Live rollover
      on device NOT verified — pending owner device validation.

### Validation

Unit tests for inbox drain idempotency and same-day precedence;
`verify-on-sim` run — tap the intent, screenshot the state flip, foreground
the app, and show the saved `CheckInRecord` via dev menu or log excerpt.

**Ship gate (2026-07-25):** rebased onto staging after the 21.2/21.3 and
21.4 merges (additive conflict resolution across the WidgetSnapshot client
+ `Package.swift`); `swift test` 648/648 in 121 suites, `make lint` 0
violations, `CheckInWidgetView` references recorded on the pinned sim (6
PNGs: unlogged/logged/stale × light/dark; all pre-existing references
byte-unchanged), full `make test-snapshots` 0 ✘ TEST SUCCEEDED, sim
`xcodebuild … CoachApp … build` succeeded. The live `verify-on-sim` intent
tap/foreground-drain flow remains pending owner device validation, per
epic convention.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
