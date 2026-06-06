# Epic 07 — Today — daily brief

Status: planned
Created: 2026-06-06
Depends on: Epic 04, Epic 05, Epic 06

## Overview

Builds the hero "Today" screen from the daily brief: the check-in + morning orchestration
(check-in → sync → brief) with all loading/error states, the readiness gauge + forced-REST
state, the shared `SessionFeature` (card + alternatives + skipOk), and the nutrition +
yesterday-intake halves. The centre of gravity of the app.

## Architecture references

- [ARCHITECTURE.md §8, §11, §12, §14](../../architecture/ARCHITECTURE.md) — features, the app-open orchestration, error flow, caching/offline.
- [PRD §6, §7.2, §7.4, §8.1–8.6](../../product/PRD-iOS-UX.md) — the loop, check-in, daily-brief sub-components, the state model.
- [openapi.yaml](../../architecture/openapi.yaml) — `DailyBrief` / `DailyBriefData` shape.
- [Screens](../../design/screens/) — Today Exercise, Today Exercise Off-day, Today Why open, Today Nutrition.

## Dependencies

- Epic 04, Epic 05, Epic 06

## Out of scope

- Weekly plan (Epic 08); Settings / notifications (Epic 09).
- Trends (out of v1, D20).

## Phase 7.1 — Check-in + morning orchestration

**Plan**: _not yet created_

**Goal**: Build the daily check-in component (3 inputs, upsert, validation) and the check-in/sync/daily-brief orchestration effect with loading/generating/sync-failed/error states.

### What to build

- `CheckInComponent` (giSymptoms toggle, illness toggle, kneePain 0–10 stepper; upsert-by-date; out-of-range impossible).
- The `TodayFeature` orchestration effect: check-in → `SyncRepository` → `BriefRepository` (daily), with the universal state model (idle / syncing / generating / ready[fresh|cached] / sync-failed / error) and a debounced Refresh.

### Acceptance criteria

- [ ] The orchestration runs sync before the brief; a sync failure blocks with the "couldn't sync" + retry state; cache hits resolve instantly.
- [ ] The check-in is upsertable same-day; editing then refreshing regenerates the brief; skipping the check-in still allows a brief.
- [ ] TestStore covers the full sequence incl. the failure and cache-hit branches.

### Validation

TestStore drives the sequence with stubbed repos across success / sync-fail / cache-hit; snapshot the loading / generating / sync-failed states.

---

## Phase 7.2 — Readiness + forced-REST

**Plan**: _not yet created_

**Goal**: Build the readiness gauge with the penalties why breakdown and the distinct safety-gate forced-REST screen.

### What to build

- The readiness section (gauge + tappable itemized penalties "why", §7.4.1).
- The distinct forced-REST screen (safetyGate.triggered → calm reason copy, the override session, empty alternatives) vs the coach-chosen easy day (not forced-REST).

### Acceptance criteria

- [ ] Readiness renders score / band + the penalty breakdown with mapped labels; readiness ignores the check-in (physiological only).
- [ ] A tripped gate shows the calm forced-REST screen with the mapped reason + the override session; an untripped easy day shows a normal session.
- [ ] TestStore + snapshots cover green / amber / red and a forced-REST variant.

### Validation

Use the mock forced-REST scenarios; snapshot the off-day + why-open states (matching the designs).

---

## Phase 7.3 — SessionFeature (promoted shared)

**Plan**: _not yet created_

**Goal**: Build the shared SessionFeature reducer+view: session card, alternatives (swap), skipOk, and the session narrative.

### What to build

- The shared `SessionFeature` (its own target): renders a `SessionBlock` via `SessionCard`, presents ≤2 alternatives with a swap action, the warm `skipOk` affordance, and the `session` narrative. Consumed by Today (and later Weekly).

### Acceptance criteria

- [ ] Selecting an alternative swaps the displayed session; `skipOk=true` surfaces the permission-to-skip affordance.
- [ ] `effort_based` (long run) de-emphasizes the HR ceiling; `append_to_easy` strides attach to the run.
- [ ] TestStore covers swap / skip; snapshots cover representative sessions.

### Validation

TestStore for the swap / skip actions; snapshot the session card with alternatives in light + dark.

---

## Phase 7.4 — Nutrition + yesterday intake

**Plan**: _not yet created_

**Goal**: Build the MacroFocus nutrition panel (day type) and the yesterday intake-vs-target recap with its empty state.

### What to build

- The `MacroFocus` nutrition panel (day type prominent; calories, protein, carbs, fat range, hydration range), co-equal with the workout, paired with the `nutrition` narrative.
- The yesterday intake-vs-target recap (calories %, protein hit/missed, water/fiber) with the "no food logged" empty state for null `intakeYesterday`.

### Acceptance criteria

- [ ] Nutrition shows day type + targets with ranges as ranges and protein emphasized; pairs the nutrition narrative.
- [ ] The yesterday recap shows calories % + protein hit/missed; a null `intakeYesterday` renders the empty state (not zeros).
- [ ] TestStore + snapshots cover a logged day and the empty state.

### Validation

Mock scenarios for logged + no-food-logged; snapshot both (matching the Today Nutrition design).

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
