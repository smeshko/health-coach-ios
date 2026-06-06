# Epic 09 — Settings & notifications

Status: planned
Created: 2026-06-06
Depends on: Epic 03, Epic 04, Epic 06

## Overview

Adds the settings surface and the app-local reminders that compensate for the no-server-push
model: the `NotificationClient`, the `SettingsFeature` (connection, HealthKit status, last sync,
read-only profile constants), and the scheduling/management of the morning check-in and weekly
strength-test reminders.

## Architecture references

- [ARCHITECTURE.md §6, §7, §2 (D21)](../../architecture/ARCHITECTURE.md) — NotificationClient, ProfileRepository, local notifications.
- [PRD §6, §7.3, §7.7, §11](../../product/PRD-iOS-UX.md) — the loop / no-push model, strength-test cadence, settings, the open notification question.
- [Screens](../../design/screens/) — Settings (light / dark).

## Dependencies

- Epic 03, Epic 04, Epic 06

## Out of scope

- Today / Weekly features (Epics 07–08).
- Server-side scheduling (none exists; all reminders are app-local).

## Phase 9.1 — NotificationClient

**Plan**: _not yet created_

**Goal**: Build the UserNotifications-backed NotificationClient (authorization + schedule/cancel).

### What to build

- `NotificationClient` interface + live over UserNotifications: request authorization, schedule, and cancel identified local notifications; test/preview values.

### Acceptance criteria

- [ ] The client requests notification authorization and can schedule / cancel identified local notifications.
- [ ] The test value records scheduling calls without touching the system.

### Validation

Unit-test schedule / cancel via the test value; manual authorization + a fired local notification on device.

---

## Phase 9.2 — SettingsFeature

**Plan**: _not yet created_

**Goal**: Build the SettingsFeature: connection state, HealthKit status with a path to Health settings, last-sync time, and read-only profile constants.

### What to build

- `SettingsFeature`: connection / token state (with a re-connect path), HealthKit permission status + a link to the iOS Health settings when categories are missing, last-sync time, and read-only profile constants (age, zones, baselines) from `ProfileRepository`. No account / logout. Matches the Settings design.

### Acceptance criteria

- [ ] Settings shows the connection state, per-category HealthKit status with a path to Health, last-sync time, and read-only constants.
- [ ] Re-connecting (token) is reachable; there is no account / logout.
- [ ] TestStore + snapshot (light + dark) cover the screen.

### Validation

TestStore with stubbed repos for the states; snapshot the settings screen.

---

## Phase 9.3 — Local reminders wiring

**Plan**: _not yet created_

**Goal**: Schedule/manage the morning check-in and weekly strength-test local reminders, wired to NotificationClient with a settings toggle.

### What to build

- Scheduling / management of the morning check-in reminder and the weekly strength-test reminder (the app prompts, since there's no scheduler), wired to `NotificationClient`, with a settings toggle to enable / disable.

### Acceptance criteria

- [ ] Enabling reminders schedules the morning check-in (and weekly strength-test) notifications; disabling cancels them.
- [ ] The strength-test prompt cadence is ~weekly and re-testing in a week overwrites (the server keys by ISO week).
- [ ] TestStore covers enable / disable scheduling via the client test value.

### Validation

TestStore: toggle on / off and assert schedule / cancel calls; manual end-to-end on device.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
