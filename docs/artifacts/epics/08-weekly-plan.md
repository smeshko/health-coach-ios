# Epic 08 — Weekly plan

Status: planned
Created: 2026-06-06
Depends on: Epic 04, Epic 05, Epic 06, Epic 07

## Overview

Builds the "This Week" screen — a menu-with-budgets, not a calendar: new-ISO-week detection +
weekly fetch/cache and the budgets header, the core/extra session groups (reusing
`SessionFeature`) with suggested-day hints and the hard-day rhythm, and the co-equal weekly
nutrition (carb-cycling pattern + constants + last-week adherence).

## Architecture references

- [ARCHITECTURE.md §8, §11, §14, §17.2](../../architecture/ARCHITECTURE.md) — features, the new-week trigger, caching, and the open time/ISO-week decision.
- [PRD §7.5](../../product/PRD-iOS-UX.md) — the weekly-plan sub-components.
- [openapi.yaml](../../architecture/openapi.yaml) — `WeeklyPlan` / `WeeklyPlanData`, `WeeklyNutrition`, `RestDayNutrition`, `LastWeekNutrition`.
- [Screens](../../design/screens/) — Weekly designs pending; build to the PRD.

## Dependencies

- Epic 04, Epic 05, Epic 06, Epic 07

## Out of scope

- Today (Epic 07); Settings / notifications (Epic 09); Trends (out of v1).

## Phase 8.1 — New-week detection + weekly shell + budgets

**Plan**: _not yet created_

**Goal**: Build new-ISO-week detection + weekly fetch/cache, the WeeklyFeature shell, the plan narrative, and the budgets header (incl. deload).

### What to build

- `WeeklyFeature` shell + new-ISO-week detection (per the §17.2 approach) triggering the weekly fetch/cache, the `plan` narrative lead, and the budgets header (hard days · strength · long run; deload badge + warm explanation).

### Acceptance criteria

- [ ] On a new ISO week the weekly brief is fetched once and cached for the week; re-opens serve the cache.
- [ ] The budgets header renders the counts; `deload=true` badges the week as a lighter recovery week.
- [ ] TestStore covers fetch-on-new-week + cache; a snapshot covers the header (incl. deload).

### Validation

TestStore with a stubbed clock/repo: a new week triggers a fetch, the same week serves cache; snapshot budgets + deload.

---

## Phase 8.2 — Core/extra sessions + targets

**Plan**: _not yet created_

**Goal**: Render core and extra sessions (reusing SessionFeature) with suggested-day chips and hard-day marking, plus the weekly targets strip.

### What to build

- Two groups — Core (do these) and Extras (optional) — each a `SessionFeature` card with a suggested-day chip (a hint, not an appointment) and hard-day marking.
- The weekly targets strip (total km, easy-run ratio, strength, hard days, cadence cue).

### Acceptance criteria

- [ ] Core / extra render distinctly; the suggested day is communicated as a hint; hard days are marked.
- [ ] The targets strip shows the numbers incl. the cadence cue; the easy-run ratio is presented as the "80% easy" split.
- [ ] Snapshots cover the core + extra groups and the targets strip.

### Validation

Snapshot the session groups + targets from a mock weekly plan; confirm `SessionFeature` reuse without regressions.

---

## Phase 8.3 — Weekly nutrition + adherence

**Plan**: _not yet created_

**Goal**: Build the weekly carb-cycling pattern, the constant targets, the rest-day cut, and the last-week adherence scorecard with empty states.

### What to build

- The carb-cycling pattern (a row of day types with carb/calorie targets, incl. the rest-day cut), the constant targets (protein, fat range, hydration), and the last-week adherence scorecard (avg calories, avg protein, protein-hit days, days over/under) with the "not enough data" empty state for a null `lastWeek`.

### Acceptance criteria

- [ ] The week's day types render as a pattern showing carbs riding up around hard days / down on rest days (incl. `restDay`).
- [ ] The adherence scorecard renders when present and shows the empty state when `lastWeek` is null; tone stays encouraging.
- [ ] Snapshots cover the pattern + scorecard (present + empty).

### Validation

Mock weekly scenarios (with / without `lastWeek`); snapshot the pattern + scorecard states.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
