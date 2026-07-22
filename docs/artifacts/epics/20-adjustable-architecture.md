# Epic 20 — Make it adjustable (audit wave 3)

Status: implemented — owner device validation pending
Created: 2026-07-05
Depends on: Epic 19
Project: audit-remediation-2026-07
Linear: none
Milestone: none

## Overview

Third remediation wave: pay down the maintainability debt the Architecture lens
flagged so future adjustments touch one place, not five. The layering is sound, but
domain rules are physically duplicated across modules with no parity guard, failures
are swallowed by an error-handling house style that shows an empty screen instead of
a retry, the Weekly tab breaks its own cache-first invariant, and log rotation state
is never restored. None of this blocks running the app (waves 1–2 do that); this
wave makes the codebase safe to change — the stated goal of the whole audit. Ordered
last so it settles on top of the corrected behaviour from Epics 18–19.

## Architecture references

- [docs/ARCHITECTURE.md](../../ARCHITECTURE.md) — layer ownership rules and the
  single-source-of-truth expectations this epic re-establishes.
- [docs/artifacts/audits/AUDIT-2026-07-05.md](../audits/AUDIT-2026-07-05.md) —
  Architecture/Adjustability lens verdict and the SSOT-drift findings.

## Dependencies

- **Epic 19** — consolidate around the *corrected* domain rules (e.g. readiness
  banding, enum maps) rather than deduping a still-buggy implementation.

## Out of scope

- Borderline/Low doc-comment-drift tail beyond the High/Medium items — swept
  opportunistically, not scoped as phases here.
- Any new feature work — this wave is strictly debt paydown.

## Phase 20.1 — SSOT consolidation

**Plan**: [phase-20-1-ssot-consolidation](../plans/archive/2026-07-23-phase-20-1-ssot-consolidation/PLAN.md) · status: done · **PR #65**

**Linear**: none

**Goal**: Collapse duplicated domain rules (readiness band, wire-string enum maps, weekday match) to a single source with a parity guard.

### What to build

- Route the readiness-band highlight in
  `Sources/DesignSystem/Sources/Primitives/SegmentedBar.swift` through the domain
  `ReadinessBand` SSOT instead of re-deriving bands from hardcoded 50/75 thresholds.
- Collapse the triplicated flag wire-string map
  (`Sources/Models/DomainModels/Sources/Flag.swift`) and the duplicated open-enum
  maps (`Sources/Models/WireDomainMapping/Sources/EnumMapping.swift` vs the
  DomainModels Codable inits) to one owner, and add a parity guard (test) so the
  two can't silently diverge again.
- Make the `suggestedDay` match in
  `Sources/DesignSystem/Sources/Composites/CarbCyclingPattern.swift` case-insensitive
  (or map through the enum) so a case-mismatched entry doesn't silently render as a
  rest day.

### Acceptance criteria

- [x] Readiness banding is computed in exactly one place; the view consumes it.
- [x] Each wire-string enum map has a single owner and a parity test that fails if
  a case is added on one side only.
- [x] `suggestedDay` matching no longer drops valid entries on case mismatch.

### Validation

Add a new enum case and show the parity test forces both sides updated; show the
readiness band and a mixed-case `suggestedDay` render correctly.

---

## Phase 20.2 — Surface silent failures

**Plan**: none (direct implementation, spec-sized) · status: done · **PR #64**

**Linear**: none

**Goal**: Render load/save failures with an error and retry affordance in Settings and Strength-test instead of a silent empty screen.

### What to build

- In `Sources/Features/SettingsFeature/Sources/SettingsFeatureView.swift`, render
  the `LoadState` failed/loading cases (currently never shown) with an error message
  and a retry affordance instead of a silently empty screen.
- In `Sources/Features/StrengthTestFeature/Sources/StrengthTestFeature.swift` (and
  its view), surface a save failure as user-visible state (message/haptic) rather
  than swallowing it.

### Acceptance criteria

- [x] A failed Settings load shows an error with a working retry, not a blank screen.
- [x] A failed Strength-test save is visible to the user and recoverable.

### Validation

Inject a load failure and a save failure; screenshot the error + retry states on
the simulator.

---

## Phase 20.3 — Weekly-tab reliability and dead-machinery cleanup

**Plan**: none (direct implementation, spec-sized) · status: done · **PR #63**

**Linear**: none

**Goal**: Honor cache-first on the Weekly tab and wire or remove the unreachable refresh and unread new-week machinery.

### What to build

- In `Sources/Features/WeeklyFeature/Sources/WeeklyFeature.swift`, stop the `.task`
  from unconditionally resetting a `.ready` screen to full-screen `.loading` on every
  tab re-appear (it contradicts the app's cache-first invariant, so a stale/bad plan
  is week-long-permanent with no escape).
- Wire the unreachable manual `refreshTapped` path to a control, or remove it; and
  remove or genuinely consume the `lastSeenISOWeek` / `isNewWeek` watermark
  machinery that is written but never read (and whose doc comment misleads).

### Acceptance criteria

- [x] Re-entering the Weekly tab with a cached plan does not force a full-screen
  reload (cache-first honored).
- [x] There is a reachable refresh, or the dead refresh path is removed.
- [x] `lastSeenISOWeek`/`isNewWeek` is either consumed in production or removed,
  with docs matching reality.

### Validation

Navigate away and back to the Weekly tab and show it stays rendered from cache; show
refresh either works from the UI or is gone; grep shows no orphan watermark writes.

---

## Phase 20.4 — LogClient rotation persistence

**Plan**: none (direct implementation, spec-sized) · status: done · **PR #62**

**Linear**: none

**Goal**: Restore rotation state at launch so the size cap holds and recent-line ordering survives relaunch.

### What to build

- In `Sources/Clients/LogClient/Live/LogFileWriter.swift`, restore rotation state
  from disk at launch so files can't grow past `maxBytes` across relaunches and
  `readRecent` returns chronologically-ordered lines after a restart.

### Acceptance criteria

- [x] Log files stay within `maxBytes` across app relaunches (rotation state
  survives).
- [x] `readRecent` returns lines in chronological order after a restart.

### Validation

Write logs across a simulated relaunch; show the file respects the size cap and
`readRecent` ordering is correct.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [x] Each consolidated domain rule has a single owner and a parity guard; a
  foreseeable change (new enum case, tweaked band threshold) touches one place.
- [x] Load/save failures are user-visible and recoverable across the app.
- [x] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done` (pending owner device validation)
