# Epic 03 — Data sources

Status: planned
Created: 2026-06-06
Depends on: Epic 01, Epic 02

## Overview

Implements the low-level I/O clients the repositories sit on — the URLSession `APIClient` (with
the `Endpoint<Response>` transport, auth, retry, and the 401 session stream) and `TokenClient`,
the GRDB `Database` client, and the `HealthKitClient` — each split into interface + live targets
with test/preview values. Pure plumbing: no domain mapping, no caching policy.

## Architecture references

- [ARCHITECTURE.md §6 + §6.1](../../architecture/ARCHITECTURE.md) — the data-source clients + the APIClient routing/transport design.
- [ARCHITECTURE.md §2 (D6, D8, D11, D12, D13)](../../architecture/ARCHITECTURE.md) — interface/live split, custom URLSession, HealthKit role, Keychain token, the 401 stream.
- [openapi.yaml](../../architecture/openapi.yaml) — the six routes + auth/error semantics.
- [PRD §5, §7.1, §8.3–8.4](../../product/PRD-iOS-UX.md) — the HealthKit read set, sync mechanics, error/auth behavior.

## Dependencies

- Epic 01, Epic 02

## Out of scope

- DTO↔domain mapping and caching policy (Epic 04 repositories).
- The mock/live toggle and `DevSettingsClient` (Epic 04).
- Any UI consuming permissions (Epic 06).

## Phase 3.1 — APIClient + TokenClient

**Plan**: _not yet created_

**Goal**: Build the URLSession transport with Endpoint<Response> routes, auth-header injection, envelope decoding, 502/504 retry, the 401 session stream, and the Keychain TokenClient.

### What to build

- The `Endpoint<Response>` route descriptions + a generic `send<R>` transport over URLSession (auth-header injection except `/health`, error-envelope→`APIError` decoding, 502/504 retry to the ~60 s cap, per-endpoint retry/timeout/requiresAuth).
- The `APIClient` interface (typed closures: `health`, `probe`, `sync`, `dailyBrief(date:refresh:)`, `weeklyBrief(isoWeek:refresh:)`, `profile`) + `APIClientLive` + test/preview values.
- A `SessionEvent` `AsyncStream` the transport publishes 401s on.
- `TokenClient` (interface + live) reading/writing/clearing the Keychain.

### Acceptance criteria

- [ ] Request-building tests assert the correct URL/method/query/body/headers for all six routes (incl. `requiresAuth=false` for `/health` and the `refresh`/body params).
- [ ] Non-2xx envelopes decode to typed `APIError` per code; 502/504 retry; a 401 emits on the session stream without retrying.
- [ ] `TokenClient` round-trips a token through the Keychain; its test value is in-memory.

### Validation

Run the transport tests against a stubbed `URLProtocol`; confirm retry / 401-stream / envelope-decode behavior and the Keychain round-trip.

---

## Phase 3.2 — Database (GRDB) client

**Plan**: _not yet created_

**Goal**: Stand up the GRDB DatabaseQueue, migrations, and read/write/observe primitives behind the Database client.

### What to build

- `Database` interface + `DatabaseLive` over a single GRDB `DatabaseQueue`: schema migrations for the persistence records, typed read/write, and `ValueObservation`→`AsyncStream` observe primitives.
- A test value backed by an in-memory database.

### Acceptance criteria

- [ ] Migrations create the schema for all cached entities on first launch and are idempotent.
- [ ] Read/write/observe primitives work against an in-memory DB in tests; an observed query emits on change.

### Validation

Run DB tests on an in-memory queue: migrate, write, read back, and assert an observation emits after a write.

---

## Phase 3.3 — HealthKitClient

**Plan**: _not yet created_

**Goal**: Wrap HealthKit authorization/status and delta reads of the RecordType set into the HealthKitClient.

### What to build

- `HealthKitClient` interface + live: authorization request + per-type authorization status (for the degraded UX), and delta reads for the `RecordType` set + workouts + activity since a passed-in anchor/date, returning plain payload structs.
- Test/preview values returning canned samples (from `SampleData`).

### Acceptance criteria

- [ ] The client requests read access for the full `RecordType` set and exposes per-category status.
- [ ] Delta reads return only samples newer than the anchor; categories with no permission return empty, not errors.
- [ ] The test value yields deterministic canned samples without touching real HealthKit.

### Validation

Run client tests against the test value; manually verify the authorization sheet and a delta read on a simulator/device.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
