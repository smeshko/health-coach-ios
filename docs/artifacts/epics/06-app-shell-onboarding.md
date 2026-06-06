# Epic 06 — App shell & onboarding

Status: planned
Created: 2026-06-06
Depends on: Epic 03, Epic 04, Epic 05

## Overview

Assembles the app spine: the tab-root `AppFeature` with the onboarding↔main switch and global
401 routing, the Connect (token) flow validated via `GET /probe`, HealthKit priming + the
degraded-permissions state, and a DEBUG dev menu for the mock/live toggle + scenario picker.
After this epic the app launches, connects, authorizes, and is navigable end-to-end (against
mocks).

## Architecture references

- [ARCHITECTURE.md §10, §13 + §2 (D7, D12, D13)](../../architecture/ARCHITECTURE.md) — navigation, auth/401 routing, token entry.
- [ARCHITECTURE.md §7.1](../../architecture/ARCHITECTURE.md) — the dev-menu toggle §6.4 surfaces.
- [PRD §5, §7.7, §8.4](../../product/PRD-iOS-UX.md) — onboarding/permissions, settings, auth failure.
- [Screens](../../design/screens/) — Connect, Connect Error, HealthKit Priming, Degraded.

## Dependencies

- Epic 03, Epic 04, Epic 05

## Out of scope

- The Today / Weekly / Settings feature content (Epics 07–09); this epic provides the shell + tabs + onboarding only.

## Phase 6.1 — AppFeature shell + 401 routing

**Plan**: _not yet created_

**Goal**: Build the tab-root AppFeature with the onboarding/main switch and the global 401 session-stream routing.

### What to build

- The tab-root `AppFeature` (`.onboarding` vs `.main` with per-tab `StackState`) and a long-running effect subscribing to the `APIClient` session stream that swaps to Connect on a 401 (clearing in-flight effects, no retry loop).
- The live-dependency composition root that installs the routed repositories.

### Acceptance criteria

- [ ] The app shows onboarding until connected + authorized, then the tab bar; per-tab stacks drill down independently.
- [ ] A simulated 401 from any call routes to Connect with `reason: tokenInvalid` and no retry loop.
- [ ] TestStore tests cover the onboarding↔main switch and the 401 routing effect.

### Validation

TestStore: emit a 401 session event and assert the state swaps to onboarding; a manual run shows the tabs after connect.

---

## Phase 6.2 — Connect (token) flow

**Plan**: _not yet created_

**Goal**: Build the OnboardingFeature Connect screen: paste token, validate via GET /probe, store in Keychain, plus connect-error states.

### What to build

- `OnboardingFeature` Connect screen: paste token → validate via `GET /probe` → on 200 store in Keychain (TokenClient) and advance; on 401 / failure show the connect-error state. Matches the Connect / Connect Error designs.

### Acceptance criteria

- [ ] A valid token (probe 200) is stored and advances onboarding; an invalid token (probe 401) shows the error state without storing.
- [ ] Re-entering a token is the recovery path (no account / recovery flow).
- [ ] TestStore + snapshot (light + dark) cover the connect + error states.

### Validation

TestStore: stub probe success/failure and assert storage + transitions; snapshot the two states.

---

## Phase 6.3 — HealthKit priming + degraded

**Plan**: _not yet created_

**Goal**: Build HealthKit permission priming, authorization, and the degraded-permissions state.

### What to build

- A permission-priming screen explaining why each category matters, triggering `HealthKitClient` authorization, and the degraded-permissions state (partial grants → proceed with a "missing X" hint). Matches the HealthKit Priming / Degraded designs.

### Acceptance criteria

- [ ] Priming explains the categories before the system sheet; granting advances to the app.
- [ ] Partial / declined permissions proceed in a degraded state that surfaces what's missing (not a hard block).
- [ ] TestStore + snapshots cover the primed, granted, and degraded states.

### Validation

TestStore with a stubbed client for grant / partial / deny; snapshot priming + degraded.

---

## Phase 6.4 — DEBUG dev menu

**Plan**: _not yet created_

**Goal**: Surface a DEBUG-only dev menu to flip the global mock/live toggle and pick per-endpoint scenarios.

### What to build

- A DEBUG-only dev menu (reachable from the shell) to flip the global `useMockData` toggle and pick the per-endpoint scenario, writing through `DevSettingsClient`; absent in RELEASE.

### Acceptance criteria

- [ ] The dev menu toggles mock/live and selects scenarios at runtime (instant, per §7.1).
- [ ] The control is compiled out of RELEASE builds.

### Validation

Manual: toggle to mock, pick a forced-REST scenario, and confirm subsequent brief reads reflect it without relaunch.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
