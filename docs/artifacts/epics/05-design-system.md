# Epic 05 — Design system

Status: planned
Created: 2026-06-06
Depends on: Epic 01, Epic 02

## Overview

Packages the PRD's fixed visual vocabulary into the `DesignSystem` target — color/type/spacing
tokens, the enum→label mappings (the "never show raw keys" boundary), and the reusable components
(session card, zone chip, gauges, badges, nutrition panel, narrative renderer) — all pure (state
in / view out) and snapshot-tested in isolation, built against the design-system references.

## Architecture references

- [ARCHITECTURE.md §9 + §2 (D16, D19)](../../architecture/ARCHITECTURE.md) — the DesignSystem target + snapshot config.
- [PRD §4, §9, §12](../../product/PRD-iOS-UX.md) — the vocabulary, accessibility/copy rules, and enum→label tables.
- [Design system references](../../design/design-system/) — Colors, Typography, Spacing & Radii, Iconography.
- [Screens](../../design/screens/) — the rendered screens these components compose.

## Dependencies

- Epic 01, Epic 02

## Out of scope

- Feature reducers / state (Epics 06+); components here are stateless views.
- The domain enums themselves (Epic 02); this epic maps them to labels/colors.

## Phase 5.1 — Tokens + enum-to-label maps + snapshot harness

**Plan**: _not yet created_

**Goal**: Establish DesignSystem color/type/spacing tokens, the enum-to-label mappings (PRD §12), and the snapshot-test harness (light+dark, single device, states).

### What to build

- Color tokens (traffic-light bands, cool→hot zones, intensity accents) always paired with a label/icon (a11y, §9.4); typography; spacing/radii — matching the design-system references.
- The enum→label mappings for every PRD §12 table (card, flag, band, day type, intensity, penalty factor, safety reason, error code, tier, weekday, zone).
- The snapshot-test harness preset (light+dark, single reference device) reusable by component/feature snapshot targets.

### Acceptance criteria

- [ ] Tokens match the design-system reference images (colors / type / spacing) and never rely on color alone.
- [ ] Every PRD §12 enum has a human label; no raw machine key is renderable.
- [ ] A trivial component snapshot passes in light + dark via the shared harness.

### Validation

Snapshot a swatch/label catalog in light + dark and review against the design-system references.

---

## Phase 5.2 — Session components

**Plan**: _not yet created_

**Goal**: Build the session vocabulary components: SessionCard, ZoneChip, FlagBadge, DayTypeTag.

### What to build

- `SessionCard` (card name, duration range, zone chip, HR cap, cadence cue, intensity accent, flag footnotes), `ZoneChip` (zone + bpm range from profile), `FlagBadge` (typed flag → quiet badge), `DayTypeTag`.

### Acceptance criteria

- [ ] `SessionCard` renders a `SessionBlock` / `PlannedSession` domain model incl. optional HR cap / cadence and the `append_to_easy` / `effort_based` treatments.
- [ ] `ZoneChip` shows the zone label + its bpm range; `FlagBadge` shows mapped labels (incl. `.unknown` gracefully).
- [ ] Snapshots cover representative cards (easy_run, long_run effort-based, boxing, rest) in light + dark.

### Validation

Snapshot each component across representative inputs; review for at-a-glance legibility (large numbers, §9.4).

---

## Phase 5.3 — Brief components

**Plan**: _not yet created_

**Goal**: Build ReadinessGauge, NutritionPanel/MacroRow, and the ordered NarrativeRenderer.

### What to build

- `ReadinessGauge` (score + band color + label), `NutritionPanel` / `MacroRow` (day type, calories, protein, carbs, fat range, hydration range), and `NarrativeRenderer` (renders `narrative[]` in order, styled by `type`, basic markdown).

### Acceptance criteria

- [ ] `ReadinessGauge` renders green / amber / red with score + label and a "why" affordance hook.
- [ ] `NutritionPanel` shows ranges as ranges (e.g. 65–80 g) and emphasizes protein; `NarrativeRenderer` preserves section order and renders `caution` set-apart and non-alarming.
- [ ] Snapshots cover each band, day type, and the five narrative types in light + dark.

### Validation

Snapshot the components across bands / day-types / narrative-types; confirm ordering + caution styling.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
