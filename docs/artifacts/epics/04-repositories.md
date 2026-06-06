# Epic 04 — Repositories

Status: planned
Created: 2026-06-06
Depends on: Epic 02, Epic 03

## Overview

Builds the repository layer — the only seam the features see. Introduces the mock/live routing +
`DevSettingsClient` first, then each repository (`Brief`, `Sync`, `CheckIn`, `StrengthTest`,
`Profile`) with both a `.live` (network+GRDB) and a `.mock(scenario:)` value, owning caching
policy and DTO↔domain↔record mapping. After this epic all feature work can proceed against
fixtures with the backend toggled off.

## Architecture references

- [ARCHITECTURE.md §7 + §7.1](../../architecture/ARCHITECTURE.md) — repository responsibilities + the mock/live routing & dev-settings design.
- [ARCHITECTURE.md §2 (D9, D10, D23, D25)](../../architecture/ARCHITECTURE.md) — cache ownership, model layers, offline policy, the mock/live toggle.
- [openapi.yaml](../../architecture/openapi.yaml) — the endpoints each repository wraps.
- [PRD §6, §7.1–7.5, §8.2–8.6](../../product/PRD-iOS-UX.md) — the flows + cache/offline/empty-state rules repositories enforce.

## Dependencies

- Epic 02, Epic 03

## Out of scope

- The dev-menu UI for the toggle (Epic 06.4); this epic ships the mechanism + launch-arg/env access.
- Feature reducers / UI (Epics 06+).

## Phase 4.1 — Mock/live routing + DevSettings

**Plan**: _not yet created_

**Goal**: Add the DevSettingsClient (persisted global mock flag + per-endpoint scenario selection, launch-arg/env settable) and the per-call repository routing wrapper.

### What to build

- `DevSettingsClient` (interface + live): a persisted global `useMockData` flag + a per-endpoint scenario map, settable via a DEBUG launch argument / scheme env-var, with a DEBUG default.
- The generic repository routing pattern (`*.routed(dev:)`) that reads the flag per call and delegates to `.mock(scenario:)` or `.live`, collapsing to `.live` in RELEASE.

### Acceptance criteria

- [ ] `DevSettingsClient` persists the flag + scenario selection and reads an override from a launch arg / env at startup.
- [ ] The routing wrapper switches a repository between mock and live per call with no relaunch (unit-tested with a fake DevSettings).
- [ ] In RELEASE, the mock paths are compiled out / inert.

### Validation

Unit-test the routed wrapper: flip the flag mid-test and assert delegation switches; launch the app with the mock env-var and confirm mock data is served.

---

## Phase 4.2 — BriefRepository

**Plan**: _not yet created_

**Goal**: Implement BriefRepository (.live + .mock(scenario:)) for daily + weekly with the sync-gated cache policy, DTO/domain/record mapping, and refresh.

### What to build

- `BriefRepository` interface + `.live` + `.mock(scenario:)`: daily + weekly get-or-generate with the sync-gated cache policy (serve today's cached brief; require sync; refresh via `?refresh=true`), DTO↔domain↔record mapping, and persistence to GRDB.
- Map `APIError` (502/504/500/422) to domain errors per PRD §8.3.

### Acceptance criteria

- [ ] `.live` serves a same-day cached brief without a network call; a missing cache + sync failure surfaces `.syncRequired`; refresh forces regeneration.
- [ ] `.mock(scenario:)` returns the selected `SampleData` scenario (incl. forced-REST + empty intake).
- [ ] Mapping + cache-policy unit tests pass for daily and weekly.

### Validation

Unit-test cache hit/miss, refresh, and error mapping with stubbed APIClient/Database; exercise each mock scenario.

---

## Phase 4.3 — SyncRepository

**Plan**: _not yet created_

**Goal**: Implement SyncRepository: read HealthKit deltas since the watermark, build the sync payload, POST /sync, advance the watermark (.live + .mock).

### What to build

- `SyncRepository` interface + `.live` + `.mock`: read HealthKit deltas since the watermark, attach today's check-in (+ strength test when due), build `SyncRequest`, POST `/sync`, and on success advance the watermark + store `serverTime`.
- Idempotent / freely retryable; zero-upsert is success.

### Acceptance criteria

- [ ] A sync builds the payload from HK deltas + inputs and advances the watermark only on success.
- [ ] Re-syncing with no new data succeeds with zero upserts (not an error).
- [ ] `.mock` simulates a successful sync without HK / network.

### Validation

Unit-test payload assembly, watermark advance-on-success / no-advance-on-failure, and the zero-upsert path with stubbed clients.

---

## Phase 4.4 — CheckIn & StrengthTest repositories

**Plan**: _not yet created_

**Goal**: Implement CheckInRepository and StrengthTestRepository with local upsert-by-date and feeding the sync payload (.live + .mock).

### What to build

- `CheckInRepository` + `StrengthTestRepository` (interface + `.live` + `.mock`): local upsert-by-date of the check-in (3 fields, editable, latest-wins) and the two strength numbers, providing them to `SyncRepository`.

### Acceptance criteria

- [ ] Submitting then editing the same-day check-in keeps the latest; reads return today's value.
- [ ] Strength test upserts by date (server keys by ISO week; the app just sends the numbers).
- [ ] `.mock` variants return canned values.

### Validation

Unit-test upsert / latest-wins for the check-in and strength test against an in-memory DB.

---

## Phase 4.5 — ProfileRepository

**Plan**: _not yet created_

**Goal**: Implement ProfileRepository over GET /profile (athlete/zones/thresholds/meta) with recompute handling (.live + .mock).

### What to build

- `ProfileRepository` interface + `.live` + `.mock`: fetch `GET /profile` (athlete, HR zone ranges, thresholds, meta), cache it, expose it for zone/threshold display, and surface `constantsRecomputed`/recompute notice.

### Acceptance criteria

- [ ] `.live` fetches and caches the profile; zone bpm ranges are exposed for the ZoneChip.
- [ ] A recompute (`constantsRecomputedWeek` / `constantsRecomputed`) is surfaced.
- [ ] `.mock` returns a canned profile.

### Validation

Unit-test fetch+cache and the recompute flag with a stubbed APIClient.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
