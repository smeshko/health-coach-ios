# Epic 02 — Models & wire contract

Status: planned
Created: 2026-06-06
Depends on: Epic 01

## Overview

Builds the three model layers everything above consumes — `WireModels` (Codable DTOs mirroring
`openapi.yaml`), `DomainModels` (the app-tailored models + semantic enums the reducers/views
use), and `PersistenceModels` (GRDB records) — plus the mappings between them and the shared
`SampleData` fixtures. This is the typed vocabulary of the whole app; nothing above it touches
the wire shape directly.

## Architecture references

- [openapi.yaml](../../architecture/openapi.yaml) — the wire contract these DTOs mirror exactly.
- [ARCHITECTURE.md §5](../../architecture/ARCHITECTURE.md) — the three-layer model design + wire-contract specifics (date strategy, snake_case enum rawValues, free-string→typed enums).
- [ARCHITECTURE.md §2 (D10, D17)](../../architecture/ARCHITECTURE.md) — three model layers; the shared fixtures target.
- [PRD §12](../../product/PRD-iOS-UX.md) — the enum sets the domain models codify.

## Dependencies

- Epic 01

## Out of scope

- enum→label presentation strings (Epic 05 DesignSystem).
- The network/DB I/O that produces/persists these (Epics 03–04).
- Any caching policy (Epic 04).

## Phase 2.1 — WireModels (DTOs) + decode tests

**Plan**: _not yet created_

**Goal**: Model every openapi.yaml DTO as Codable WireModels (custom date strategy, snake_case enum rawValues), verified by decode tests against SampleData JSON.

### What to build

- Codable structs for every `openapi.yaml` schema: requests (`SyncRequest` + `HealthRecord`/`Workout`/`WorkoutStat`/`ActivitySummary`/`DailyCheckin`/`StrengthTest`, `DailyBriefRequest`, `WeeklyBriefRequest`) and responses (`SyncResponse`, `DailyBrief`/`DailyBriefData`, `WeeklyPlan`/`WeeklyPlanData`, `ProfileResponse` + sub-objects, `HealthResponse`), plus the `Error`/`ErrorResponse` envelope.
- The wire enums with explicit snake_case/lowercase rawValues (`RecordType`, `WorkoutCard`, `Zone`, `Weekday`, `Tier`, `DayType`, `Intensity`, `NarrativeType`, `ReadinessBand`, `ErrorCode`).
- Shared `JSONDecoder`/`JSONEncoder` config: camelCase keys (no key conversion) + a date strategy handling both `date` (YYYY-MM-DD) and Europe/Sofia-offset `date-time`.
- Free-string machine-key fields (`flags`, `safetyGate.reasons`, `readinessPenalty.factor`) decoded as `String`/`[String]`.

### Acceptance criteria

- [ ] Every `openapi.yaml` schema has a corresponding `WireModels` type with matching fields and optionality.
- [ ] Decode tests round-trip the `SampleData` JSON for each response, including mixed date/date-time fields and null-vs-absent optionals.
- [ ] Decoding an unknown enum rawValue (e.g. a new flag string) does not crash.

### Validation

Run the decode test suite against the canned JSON; add a fixture with an unknown flag string and confirm it decodes.

---

## Phase 2.2 — DomainModels + DTO to domain mapping

**Plan**: _not yet created_

**Goal**: Define app-tailored domain models and semantic enums (with .unknown fallbacks for free-string flags/reasons/factors) and the DTO to domain mapping.

### What to build

- App-tailored domain value types for briefs, sessions, readiness, nutrition, intake, profile/zones, non-optional where the app guarantees a default.
- Semantic enums incl. `Flag`, `SafetyReason`, `PenaltyFactor` with `.unknown(String)` fallbacks (mapped from the wire free strings) and the closed enums (`Card`, `Zone`, `ReadinessBand`, `DayType`, `Intensity`, `NarrativeType`, `Tier`, `Weekday`).
- The DTO→domain mapping functions.

### Acceptance criteria

- [ ] `DomainModels` has no `Codable`/GRDB dependency (only `CoachCore`).
- [ ] DTO→domain mapping is total: every required wire field maps, and free-string flags/reasons/factors map to typed enums with `.unknown` preserved.
- [ ] Mapping unit tests cover the daily brief, weekly plan, profile, and intake shapes incl. null intake and empty alternatives.

### Validation

Run the mapping tests; confirm an `.unknown` flag survives the round-trip carrying its raw string.

---

## Phase 2.3 — PersistenceModels + records + SampleData

**Plan**: _not yet created_

**Goal**: Add GRDB record types, the domain to record mapping, and consolidate the SampleData fixtures + factories.

### What to build

- GRDB record types for the cached entities (daily brief, weekly plan, check-in, strength test, sync watermark, profile) and the domain↔record mapping.
- The `SampleData` target: canned wire JSON resources covering the scenario set (green/amber/red readiness, forced-REST variants, no-food-logged, deload week) + domain/DTO factory helpers — the single source of sample truth for previews/tests/snapshots/mocks.

### Acceptance criteria

- [ ] Each cached entity has a GRDB record type and a lossless domain↔record mapping (unit-tested).
- [ ] `SampleData` exposes at least one fixture per documented scenario, decodable by `WireModels` and convertible to `DomainModels`.
- [ ] Snapshot/preview/test code can obtain any scenario from `SampleData` via a single helper.

### Validation

Run the record-mapping tests and a `SampleData` decode test that covers every scenario.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
