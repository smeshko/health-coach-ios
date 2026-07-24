# Epic 21 — Home-screen widgets

Status: planned
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

**Plan**: [widget-infrastructure](../plans/widget-infrastructure/PLAN.md) · status: in-progress

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

- [ ] App and extension both build and run on the canonical sim; all existing
      tests stay green.
- [ ] Refreshing the Today tab writes/updates the snapshot JSON in the App
      Group container (observable via log or dev menu).
- [ ] The skeleton widget on the sim home screen shows the snapshot's readiness
      score and date, and updates after an in-app refresh.
- [ ] The widget extension has no GRDB/Database or APIClient dependency
      (verified by its target/package dependency list).

### Validation

Package unit tests for `WidgetSnapshot` encode/decode and writer round-trip;
`verify-on-sim` run with the widget added to the home screen — screenshot
showing live data after an app refresh.

---

## Phase 21.2 — Today's session widget + lock-screen accessories

**Plan**: _not yet created_

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

- [ ] Widget shows today's selected (else planned) session with intensity,
      duration range, and zone/HR cap when the brief has them.
- [ ] Rest card and triggered safety gate render their dedicated states.
- [ ] Inline + rectangular lock-screen families render the one-line summary.
- [ ] After Sofia midnight with no new brief cached, the widget shows the
      stale state.
- [ ] Tapping any family opens the app on the Today tab.

### Validation

Snapshot tests for the widget views (all families × normal/rest/gate/stale
states) in the package test target; unit test for the midnight timeline-entry
dating; `verify-on-sim` screenshots of home-screen and lock-screen placements.

---

## Phase 21.3 — Macros widget

**Plan**: _not yet created_

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

- [ ] Targets match the cached brief's `MacroFocus` for the day; day-type
      badge follows app colors.
- [ ] Footer shows calories % and protein ✓/✗ when intake data exists, and is
      absent — without layout gaps — when it doesn't.
- [ ] Stale state after Sofia midnight, matching 21.2 behaviour.
- [ ] Tapping opens the app on the Today tab.

### Validation

Snapshot tests for small/medium × with/without intake × stale;
`verify-on-sim` screenshot alongside the session widget.

---

## Phase 21.4 — Weekly overview widget

**Plan**: _not yet created_

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

- [ ] Widget shows the current week's budgets, targets, and core sessions from
      the cached `WeeklyPlan`; deload weeks are visually flagged.
- [ ] No used/completed counts appear anywhere in the widget.
- [ ] Week rollover without a fresh plan → stale state.
- [ ] Tapping opens the app on the Weekly tab.

### Validation

Unit test for the weekly snapshot round-trip; snapshot tests (normal/deload/
stale); `verify-on-sim` screenshot with a cached weekly plan.

---

## Phase 21.5 — Interactive check-in nudge widget

**Plan**: _not yet created_

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

- [ ] Tapping "All clear" flips the widget to logged immediately, without
      opening the app.
- [ ] On next app foreground, today's `CheckIn` exists in the DB with the
      all-clear defaults; draining twice creates no duplicate.
- [ ] A check-in already logged in-app shows the logged state on the widget
      and suppresses the button; the pending inbox entry never overwrites it.
- [ ] "Symptoms…" deep-links into the app's check-in UI.
- [ ] State resets to unlogged after the Sofia-day rollover.

### Validation

Unit tests for inbox drain idempotency and same-day precedence;
`verify-on-sim` run — tap the intent, screenshot the state flip, foreground
the app, and show the saved `CheckInRecord` via dev menu or log excerpt.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
