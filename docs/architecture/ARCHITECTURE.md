# Coach App — iOS Architecture

> The engineering blueprint for the iOS client described in `docs/product/PRD-iOS-UX.md`.
> This document defines **how the app is built**: module/target structure, the data→repository→
> feature layering, navigation, error handling, caching, and the testing strategy. It is the
> companion to the PRD (which defines *what* the user sees). Where the PRD constrains an
> engineering choice, it is cited inline (e.g. §8.3).

---

## 0. How to read this document

| Section | What's in it |
|---|---|
| §1 | Guiding principles — the non-negotiables every layer inherits. |
| §2 | The decisions log — every architectural choice made, with rationale. The TL;DR. |
| §3 | The layered architecture — the big picture and the dependency rule. |
| §4 | The Swift package / target graph — the concrete module layout. |
| §5–9 | Each layer in detail: models, data sources, repositories, features, design system. |
| §10–13 | Cross-cutting: navigation, data flow, errors, caching/offline, concurrency. |
| §14 | Testing strategy. |
| §15 | Tooling & repo setup. |
| §16 | Out of scope (v1). |
| §17 | **Open decisions** — two things deliberately deferred, with recommendations. |
| §18 | Third-party dependency inventory. |

---

## 1. Guiding principles

These flow from the PRD and bind every layer.

1. **`data` builds the UI; `narrative` is rendered verbatim.** Numbers/enums come from structured
   fields and drive components; coaching prose comes from `narrative[]` and is rendered in order,
   styled by `type`. The app **never authors coaching sentences** (PRD §9.1).
2. **Never surface raw machine keys.** Every enum (`card`, `flag`, `hrv_below_baseline`, …) is
   mapped to a human label at the presentation boundary (PRD §12). Raw keys never reach a view.
3. **The reducer accesses only repositories.** Features depend on repository *interfaces* — never on
   the network client, GRDB, HealthKit, or DTOs directly. Repositories are the single seam between
   the domain and the outside world.
4. **Numbers are deterministic; the UI is dumb about coaching.** No client-side computation of
   readiness, macros, or session selection. The app transports, persists, maps, and renders.
5. **Modular by default, interface/live split everywhere.** Features compile against thin interface
   targets; live implementations (and their heavy deps) are wired only at the composition root.
   This keeps incremental builds fast and previews/tests free of live dependencies.
6. **Recovery-first UX has first-class states.** Forced-REST (safety gate, a 200 — PRD §7.4.2),
   coach-chosen easy days, and the various empty/error states are modeled explicitly, not as
   afterthoughts (PRD §8.1).

---

## 2. Decisions log

Every decision from the architecture review, in one place.

| # | Area | Decision | Rationale |
|---|---|---|---|
| D1 | Deployment target | **iOS 26+** | Single-user app; the operator controls the device. Newest APIs, full native Observation. |
| D2 | Language / concurrency | **Swift 6.3, full strict concurrency** | Greenfield; TCA is Swift-6-ready. No migration debt. |
| D3 | Project generation | **Pure SPM package + thin app target** | One `Package.swift` holds every feature/service as a library target; a minimal `.xcodeproj` app target just launches `AppFeature`. The isowords model — matches the brief exactly, zero extra tooling. |
| D4 | Local persistence | **GRDB (via SharingGRDB)** | SQLite, queryable, highly testable. Used for same-day brief cache, last-sync watermark, and check-in/strength upserts. |
| D5 | Target granularity | **Hybrid** | Each screen/feature is a target; component reducers live inside their feature **unless reused**, then promoted to their own target. Modularity where it pays, no target sprawl. |
| D6 | Dependency clients | **Interface + Live split per client** | `XClient` (interface + test/preview values) and `XClientLive` (impl) as separate targets. Features depend only on the interface. |
| D7 | Navigation | **Tab root + per-tab `StackState` + `@Presents` modals** | `AppFeature` owns the tab bar (Today / This Week / Settings); each tab drives its own drill-down stack; sheets/alerts/covers via `@Presents`. Onboarding is a top-level branch swapped in before the tabs. |
| D8 | Networking | **Custom URLSession client** | 3 endpoints; no third-party dep. Owns auth-header injection, envelope decoding, and 502/504 retry. |
| D9 | Cache ownership | **The repository owns caching + network↔local orchestration** | Network client and GRDB store are dumb data sources; the repository is the brain (cache policy, DTO→domain mapping, persistence). |
| D10 | Model representations | **Three layers: DTO + DB record + domain** | `WireModels` (Codable wire) → `DomainModels` (what reducers/views see) → `PersistenceModels` (GRDB records). Full separation; matches the single-user app's appetite for clean boundaries. |
| D11 | HealthKit | **`HealthKitClient` data source; `SyncRepository` orchestrates** | HK is a low-level client alongside network + DB. `SyncRepository` reads deltas since the watermark, maps to the sync payload, POSTs `/sync`. Features never touch HK. |
| D12 | Token storage | **Keychain via a `TokenClient` dependency** | Secure, mockable. The network client asks `TokenClient` for the header per request. Entry is **manual paste** (PRD §11 Q3). |
| D13 | 401 routing | **Global session stream → `AppFeature` routes** | The network client publishes a 401 event on an `AsyncStream`; `AppFeature` subscribes and swaps to the connect screen. No per-feature handling, no retry loop (PRD §8.4). |
| D14 | Error flow | **Layered: client→`APIError`, repo→domain error, shared presenter→UX** | The presenter is the single source of truth mapping errors to §8.3 copy + retry affordances. |
| D15 | App-open orchestration | **Reducer chains repositories in one effect** | sync → daily brief → (if new ISO week) weekly, sequenced in the reducer/effect. Repositories stay single-purpose. |
| D16 | Snapshot testing | **swift-snapshot-testing: light + dark, single reference device, multiple states** | No accessibility-variant matrix in v1. States covered: loading / ready-fresh / ready-cached / forced-REST / error / empty. |
| D17 | Fixtures | **Shared `SampleData` target: canned wire JSON + model factories** | One source of sample truth feeding decode tests, previews, snapshots, and dependency preview/test values. |
| D18 | Reducer tests | **Exhaustive `TestStore` by default** | Non-exhaustive only for deliberate integration-style subset checks. |
| D19 | Design system | **Dedicated `DesignSystem` target** | Tokens (band/zone/intensity colors) + shared components (SessionCard, ZoneChip, ReadinessGauge, FlagBadge, NarrativeRenderer) + the enum→label mappings. |
| D20 | Trends/History | **Out of v1** | No `TrendsRepository`, no long-term accumulation. GRDB is still used for same-day caching and upserts. Revisit if a backend endpoint appears (PRD §7.6, §11 Q1). |
| D21 | Local notifications | **`NotificationClient` in v1** | App-scheduled morning check-in + weekly strength-test reminders. No server push exists (PRD §6, §11 Q2). |
| D22 | Cadence metronome | **Display-only in v1** | Show `cadenceSpm` as a badge/number; defer the live in-run audio/haptic metronome (PRD §11 Q5). |
| D23 | Offline policy | **Sync-gated freshness; serve today's cache, block on sync failure** | If today's brief is cached, show it instantly. If not and sync fails → "couldn't sync" + retry. Never present a prior day's brief as today's. No synthetic fallback (PRD §8.3). |
| D24 | Tooling | **SwiftFormat + SwiftLint + `git init`; CI later** | Formatting/linting from day one; CI deferred until there's a remote. |
| D25 | Mock/live data | **Routing wrapper over clean `.mock`/`.live` repo values; single global toggle; selectable SampleData scenarios per endpoint** | Build features against fixtures with zero backend. Flag persisted + launch-arg/env overridable + DEBUG default; instant switch (no relaunch); mock code stays out of `*Live`; collapses to `.live` in RELEASE. |
| **OPEN-1** | Cross-feature shared state | **Deferred** — see §17.1 | Repositories-only vs `@Shared` for profile constants. Recommendation given. |
| **OPEN-2** | Client-side time / ISO week | **Deferred** — see §17.2 | Local Europe/Sofia calendar compute vs server-driven. Recommendation given. |

---

## 3. The layered architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  App shell (.xcodeproj)   CoachApp — @main, builds AppView(store:)      │
│                           wires live dependencies (composition root)   │
└───────────────────────────────────┬──────────────────────────────────┘
                                     │ depends on
┌────────────────────────────────────────────────────────────────────── ┐
│  FEATURES (TCA)  AppFeature · OnboardingFeature · TodayFeature ·        │
│                  WeeklyFeature · SettingsFeature · promoted components  │
│                  reducers + views; depend ONLY on repo interfaces,      │
│                  DesignSystem, DomainModels                             │
└───────────────────────────────────┬──────────────────────────────────┘
                                     │ @Dependency (interfaces only)
┌──────────────────────────────────────────────────────────────────────┐
│  REPOSITORIES  BriefRepository · SyncRepository · CheckInRepository ·  │
│  (interface +  StrengthTestRepository · ProfileRepository              │
│   live)        own caching policy + DTO↔domain↔record mapping          │
└───────────────────────────────────┬──────────────────────────────────┘
                                     │ @Dependency (interfaces only)
┌──────────────────────────────────────────────────────────────────────┐
│  DATA SOURCES  APIClient · Database · HealthKitClient · TokenClient ·  │
│  (interface +  NotificationClient                                      │
│   live)        dumb I/O; no domain knowledge                           │
└───────────────────────────────────┬──────────────────────────────────┘
                                     │
┌──────────────────────────────────────────────────────────────────────┐
│  MODELS   WireModels (DTO)  ·  DomainModels  ·  PersistenceModels       │
│  CORE     CoachCore (Tagged IDs, calendar dep, extensions)            │
└──────────────────────────────────────────────────────────────────────┘
```

**The dependency rule (enforced by target boundaries):**

- Features → repository **interfaces** + `DesignSystem` + `DomainModels`. Never DTOs, GRDB,
  URLSession, or HealthKit.
- Repository **live** → data-source **interfaces** + all three model layers (it's the only place
  that maps between them). Repository **interface** → `DomainModels` only.
- Data-source **live** → its model layer + the relevant system framework.
- Live implementations are resolved **only at the composition root** (the app target). No feature or
  repository ever imports another's `*Live` target.

---

## 4. Swift package / target graph

A single package (working name `CoachKit`) declared in `Package.swift`. The `.xcodeproj` contains one
thin app target depending on the package.

### 4.1 Core & models

| Target | Kind | Depends on | Responsibility |
|---|---|---|---|
| `CoachCore` | lib | — (maybe Tagged) | Tagged ID types, the calendar/date dependency, shared extensions, small utilities. |
| `WireModels` | lib | CoachCore | Codable DTOs matching the backend wire contract (MODELS.md). The error envelope. |
| `DomainModels` | lib | CoachCore | App-tailored domain models + semantic enums consumed by reducers/views. |
| `PersistenceModels` | lib | CoachCore, GRDB | GRDB record types (`FetchableRecord`/`PersistableRecord`) + migrations definitions. |

### 4.2 Data sources (interface + live)

| Interface target | Live target | System dep | Responsibility |
|---|---|---|---|
| `APIClient` | `APIClientLive` | URLSession | Typed endpoints; injects auth header; decodes the error envelope into `APIError`; 502/504 retry; emits the 401 stream. |
| `Database` | `DatabaseLive` | GRDB | Owns the `DatabaseQueue`, runs migrations, exposes read/write/observe primitives over `PersistenceModels`. |
| `HealthKitClient` | `HealthKitClientLive` | HealthKit | Authorization status, broad read queries, delta reads since a watermark. |
| `TokenClient` | `TokenClientLive` | Security (Keychain) | Read/write/clear the bearer token. |
| `NotificationClient` | `NotificationClientLive` | UserNotifications | Request authorization; schedule/cancel the local reminders. |
| `DevSettings` | `DevSettingsLive` | UserDefaults | DEBUG mock/live flag + per-endpoint scenario selection; drives repository routing (§7.1). Inert in RELEASE. |

All interface targets expose `liveValue` (in the `*Live` target), `testValue`, and `previewValue`
(unimplemented/canned), per the swift-dependencies convention.

### 4.3 Repositories (interface + live)

| Interface target | Live target | Depends on (live) | Responsibility |
|---|---|---|---|
| `BriefRepository` | `BriefRepositoryLive` | APIClient, Database, models | Daily brief + weekly plan: cache policy (D23), DTO→domain mapping, persistence, `?refresh=true`. |
| `SyncRepository` | `SyncRepositoryLive` | HealthKitClient, APIClient, Database | Reads HK deltas since the watermark, builds the sync payload (incl. check-in + optional strength test), POSTs `/sync`, advances the watermark. |
| `CheckInRepository` | `CheckInRepositoryLive` | Database | Local upsert-by-date of today's check-in (editable); provides it to `SyncRepository`. |
| `StrengthTestRepository` | `StrengthTestRepositoryLive` | Database | Local upsert of the two weekly numbers; provides them to `SyncRepository`. |
| `ProfileRepository` | `ProfileRepositoryLive` | Database, APIClient | Profile constants (zones/baselines) for display; refreshed when `constantsRecomputed`. |

> No `TrendsRepository` in v1 (D20).

### 4.4 Design system & fixtures

| Target | Kind | Depends on | Responsibility |
|---|---|---|---|
| `DesignSystem` | lib | DomainModels, CoachCore | Color tokens (band/zone/intensity), shared components (SessionCard, ZoneChip, ReadinessGauge, FlagBadge, NutritionPanel, NarrativeRenderer), and **all enum→label mappings** (PRD §12). |
| `SampleData` | lib (test/preview) | WireModels, DomainModels | Canned wire JSON resources + DTO/domain factories + dependency preview/test value helpers. |

### 4.5 Features

| Target | Composed of | Notes |
|---|---|---|
| `AppFeature` | tab state, onboarding switch, global 401 routing, app-open orchestration | The root. Depends on every tab feature + repo interfaces. |
| `OnboardingFeature` | ConnectComponent (token paste), HealthKitPrimingComponent | Top-level branch shown until connected + authorized. |
| `TodayFeature` | ReadinessComponent, SessionComponent\*, NutritionComponent, YesterdayIntakeComponent, CheckInComponent, SafetyRestComponent | The hero screen. Components are internal unless promoted. |
| `WeeklyFeature` | BudgetsComponent, SessionComponent\*, WeeklyNutritionComponent, AdherenceComponent | "This Week" menu-with-budgets. |
| `SettingsFeature` | ConnectionComponent, HealthKitStatusComponent, LastSyncComponent | Connection, HK status, last sync. |
| `SessionFeature`\* | SessionComponent reducer + view (card, alternatives, swap, skipOk) | **Promoted** shared component (D5) — reused by Today and Weekly. |

\* `SessionComponent` is the canonical example of a hybrid-promoted shared component: it renders a
fully-expanded session block (card name, zone chip, duration, HR cap, cadence, flags, alternatives,
`skipOk`) and is used by both Today and Weekly, so it lives in its own `SessionFeature` target.

### 4.6 Test targets

Per the SPM convention, each target gets a sibling test target:

- `*Tests` — reducer logic via exhaustive `TestStore`; repository-live mapping tests; `WireModels`
  decode tests against `SampleData` JSON.
- `*SnapshotTests` — view snapshots (D16) for each feature + each `DesignSystem` component.

---

## 5. Models — the three layers (D10)

```
        decode                map                    map
JSON ──────────▶ WireModels ──────▶ DomainModels ◀──────── PersistenceModels
(wire)            (DTO)              (reducers/views)        (GRDB record)
                     │                    ▲                       │
                     └──── repository live owns ALL mapping ──────┘
```

- **`WireModels` (DTO).** Mirror `openapi.yaml` exactly (field names, optionality, the
  `data`/`narrative` split, the error envelope). Pure `Codable`. Wire-contract specifics that shape
  these types:
  - **camelCase keys** on the wire (no key-conversion strategy), but **enum raw values are
    snake_case/lowercase** (`easy_run`, `heart_rate`, `mon`, `z1`) → explicit `rawValue`s.
  - **Mixed date formats**: `format: date` (`YYYY-MM-DD`) for `date`/`weekStart`, vs `date-time`
    with the Europe/Sofia offset for `serverTime`/`generatedAt` → a custom `JSONDecoder` date
    strategy that handles both.
  - **Free-string machine-key fields** — `flags[]`, `safetyGate.reasons[]`,
    `readinessPenalty.factor` arrive as raw `String`s; DTOs keep them as strings and `DomainModels`
    map to typed enums with an `.unknown` fallback (so a new backend flag never fails a brief).
  - **Nulls vs absent are identical** (optional → `nil`); `vsTarget` is required on `IntakeSummary`
    even when its macro totals are null.
- **`DomainModels`.** App-tailored: semantic enums (`Card`, `Zone`, `ReadinessBand`, `DayType`,
  `Intensity`, `Flag`, `NarrativeType`, `SafetyReason`, `PenaltyFactor`), value types with computed
  conveniences, non-optional where the app guarantees a default. **No Codable, no GRDB.** This is the
  only model layer features import.
- **`PersistenceModels`.** GRDB records for the cached entities (daily brief, weekly plan, check-in,
  strength test, sync watermark, profile). Independent of wire shape so the DB schema can evolve via
  migrations without touching DTOs.

Mapping lives exclusively in repository `*Live` targets. A mapping failure (e.g. a malformed brief
the server shouldn't have sent) surfaces as a domain error, not a crash.

---

## 6. Data sources

Dumb I/O. No domain knowledge, no caching decisions.

- **`APIClient`.** Six routes (per `openapi.yaml`): `health` (GET, **unauthenticated**), `probe`
  (GET — token check: 200 valid / 401 invalid; used by Connect), `sync(_:)` (POST),
  `dailyBrief(date:refresh:)` (POST, body `{date?}`), `weeklyBrief(isoWeek:refresh:)` (POST, body
  `{isoWeek?}`), `profile` (GET → athlete/zones/thresholds/meta). Injects the bearer header from
  `TokenClient` for every route except `health`. Decodes non-2xx bodies into `APIError` (the
  envelope). Retries 502/504 (briefs only) with backoff up to the ~60 s cap. On any 401, yields to
  the **session stream** before throwing.
- **`Database`.** Wraps a single `DatabaseQueue`. Exposes typed read/write and — for reactive
  features — GRDB `ValueObservation` as `AsyncStream`. Runs migrations on first launch.
- **`HealthKitClient`.** Authorization request + status (drives the degraded-permissions UX, PRD
  §5/§8.5), and delta reads of the broad type set since a passed-in anchor/date. Returns plain
  payload structs; the watermark/anchor is owned by `SyncRepository` via `Database`.
- **`TokenClient`.** `read()/write(_:)/clear()` against the Keychain.
- **`NotificationClient`.** Authorization + schedule/cancel for the morning check-in and weekly
  strength-test reminders.

### 6.1 APIClient routing & transport

Routes are described by a **phantom-typed `Endpoint<Response>` struct** (not a bare enum), with a
static factory per route, so each route carries its decoded response type:

```swift
struct Endpoint<Response: Decodable & Sendable>: Sendable {
  var method: HTTPMethod = .post
  var path: String
  var query: [URLQueryItem] = []
  var body: (@Sendable () throws -> Data)? = nil   // throwing — never try! in a computed prop
  var retry: RetryPolicy = .transientOnly          // per-endpoint policy
  var timeout: Duration = .seconds(60)
  var requiresAuth = true
}
// .health (GET, requiresAuth:false) · .probe (GET) · .sync(_:) · .dailyBrief(date:refresh:)
// · .weeklyBrief(isoWeek:refresh:) · .profile (GET)
```

This machinery is **internal to `APIClientLive`**. The public `APIClient` dependency is a struct of
**concrete typed closures** (`health`, `probe`, `sync`, `dailyBrief(date:refresh:)`,
`weeklyBrief(isoWeek:refresh:)`, `profile`) because
swift-dependencies stored closures can't be generic — the single generic executor
`send<R>(_ e: Endpoint<R>) async throws -> R` lives behind those closures.

Split of concerns:
- **Per-endpoint** (on `Endpoint`): path, query, body, retry policy, timeout, requiresAuth.
- **Cross-cutting** (once, in the transport's `send`): bearer-header injection (from `TokenClient`),
  the 401→session-stream emission (§13), error-envelope→`APIError` decoding (§12), and the 502/504
  retry loop up to the ~60 s cap.

Request-building (`Endpoint` → `URLRequest`) is unit-tested in isolation; the typed closures make the
client trivially mockable for features/repos.

---

## 7. Repositories

The only seam features see. Each repository:

1. Decides cache-first vs network-first (D9, D23).
2. Maps DTO ↔ domain ↔ persistence (D10).
3. Persists to / reads from `Database`.
4. Maps `APIError` → domain errors where it adds meaning (D14).
5. Returns `DomainModels` to reducers; optionally exposes `AsyncStream` for live updates.

**`BriefRepository.dailyBrief()`** (sync-gated freshness, D23):

```
1. If a brief for today (Europe/Sofia) is cached → return it (works offline).
2. Else: caller must have synced first. If not synced/sync failed → throw .syncRequired.
3. Else: APIClient.dailyBrief() → map DTO→domain, persist record → return domain.
4. refresh(): APIClient.dailyBrief(refresh: true) → overwrite cache → return fresh.
```

**`SyncRepository.sync()`**: read HK deltas since watermark + today's check-in (+ strength test if
due) → POST `/sync` → on success advance the watermark and store `serverTime`. Idempotent and freely
retryable (PRD §7.1). Zero-upsert is success, not an error.

### 7.1 Mock/live routing & dev settings (D25)

Each repository ships two clean dependency values:

- `.live` — network + GRDB (the real path).
- `.mock(scenario:)` — returns `SampleData` fixtures for a selected scenario; no live deps.

A thin **routing** value (`*.routed`) is what the composition root installs. Per call it reads a
`DevSettingsClient` and delegates to `.mock` or `.live`:

```swift
extension BriefRepository {
  static func routed(_ dev: DevSettingsClient) -> Self {
    let live = Self.live
    return Self(
      dailyBrief: { refresh in
        dev.useMockData()
          ? try await Self.mock(scenario: dev.scenario(.dailyBrief)).dailyBrief(refresh)
          : try await live.dailyBrief(refresh)
      }
      // …weekly, etc.
    )
  }
}
```

- **Single global switch** (`useMockData`) flips every repository at once — no per-repo mixing.
- **Per-endpoint scenario selection** in mock mode: green/amber/red readiness, forced-REST variants
  (gi_flare / illness / knee), no-food-logged, deload week, etc. Scenarios are the same `SampleData`
  fixtures used by previews and snapshot tests — one source of sample truth.
- **`DevSettingsClient`** holds the persisted flag + scenario map. Set via a DEBUG launch argument /
  scheme env-var (usable before any UI exists) and, once the shell lands, a DEBUG-only dev menu.
  Switching is instant (per-call read); no relaunch.
- In RELEASE the routing collapses to `.live`; mock paths are compiled out / inert.

---

## 8. Features (TCA)

- Reducers use `@Reducer` + `@ObservableState`. Components compose via scoping; screens are an
  assembly of component reducers (PRD's "highly modularised reducers" requirement).
- Everything **up to the view** is unit-tested with `TestStore` (exhaustive, D18). Views are covered
  by snapshot tests (D16).
- Features hold only what they render; they fetch via repository dependencies and react to repository
  `AsyncStream`s through long-running effects.
- **Forced-REST vs coach-easy** are distinct states in `TodayFeature` (PRD §7.4.2): the former is a
  dedicated calm screen (gate tripped, empty alternatives, code-written narrative); the latter is a
  normal — if gentle — session.

---

## 9. Design system (D19)

`DesignSystem` is the home of the PRD's fixed visual vocabulary and the **enum→label boundary**
(principle #2). Components are pure (state in, view out) and snapshot-tested in isolation:

- Tokens: traffic-light band colors, cool→hot zone colors, intensity accents — always paired with a
  label/icon so color is never the sole signal (PRD §9.4).
- Components: `SessionCard`, `ZoneChip`, `ReadinessGauge`, `FlagBadge`, `DayTypeTag`,
  `NutritionPanel`, `MacroRow`, `NarrativeRenderer` (renders `narrative[]` in order, styled by
  `type`, with basic markdown).
- Label mappings: every table in PRD §12 (`card`, `flag`, band, day type, intensity, penalty factor,
  safety reason, error code) lives here as the single translation point. Copy is **English-only** in
  v1 (note: Europe/Sofia is a *date* concern, not a UI-language one).

---

## 10. Navigation (D7)

```
AppFeature.State
├── .onboarding(OnboardingFeature)        // shown until connected + HK-authorized
└── .main(MainTabs)
    ├── selectedTab: Tab
    ├── today:    StackState<TodayPath>      // tab-local drill-down
    ├── weekly:   StackState<WeeklyPath>
    └── settings: StackState<SettingsPath>
// sheets / alerts / full-covers via @Presents within the relevant feature
```

The 401 session stream flips `AppFeature` from `.main` back to `.onboarding(connect)` from anywhere
(§13). A successful connect + sync flips it forward.

---

## 11. Data flow — the app-open sequence (D15)

Orchestrated in one effect in `AppFeature` (or `TodayFeature` for the Today-specific portion):

```
onAppOpen / pull-to-refresh:
  effect:
    1. CheckInRepository.current(today)            // prompt if missing, but don't hard-block
    2. SyncRepository.sync()                        // MUST precede the brief (PRD §6)
         ├─ failure → show "couldn't sync — check connection" + Retry; STOP
         └─ success ↓
    3. BriefRepository.dailyBrief()                 // get-or-generate; 3–8s spinner on miss
    4. if calendar says new ISO week (OPEN-2):
         WeeklyRepository... BriefRepository.weeklyBrief()   // "new week" moment
```

- A single generating state is always shown on a brief request; it resolves instantly on a cache hit
  and after a few seconds on a miss (PRD §8.2). The `cached` flag powers an "as of HH:MM" label, not
  the spinner decision.
- **Refresh** calls `BriefRepository.refresh()` (`?refresh=true`); the control is debounced to avoid
  refresh-spam re-rolls (PRD §8.6).
- Effects use cancellation IDs; a new app-open/refresh cancels the in-flight one.

---

## 12. Error handling (D14)

```
non-2xx envelope ──▶ APIClient decodes ──▶ APIError(code,message,detail)
                                              │
                       repository maps to domain error where useful
                                              │
                      ErrorPresenter (DesignSystem) ──▶ §8.3 UX behavior
```

| `code` | Domain handling | UX (PRD §8.3) |
|---|---|---|
| `unauthorized` (401) | → session stream | Route to connect (§13). No retry. |
| `validation_error` (422) | log as a bug | Generic "something went wrong"; controls should prevent it. |
| `not_found` (404) | generic | Rare; generic not-found. |
| `brief_generation_failed` (502) | transient | Friendly "couldn't build your brief" + Retry. |
| `upstream_timeout` (504) | transient | Same as 502 + Retry. |
| `internal_error` (500) | maybe insufficient data | On a first-ever brief → "sync your health data first" (§8.5); else Retry, no hammering. |

There is **no synthetic fallback brief** (PRD §8.3). The only "rest" shown is a legitimate
safety-gate REST (a 200) or a coach-chosen easy day.

---

## 13. Auth & the 401 path (D12, D13)

```
any request → 401 → APIClient yields on sessionEventStream (AsyncStream<SessionEvent>)
AppFeature long-running effect subscribes → on .unauthorized:
    clear in-flight effects → set state = .onboarding(.connect, reason: tokenInvalid)
```

No token-refresh protocol, no 403 path, no retry loop (PRD §8.4). The remedy is re-pasting the token,
which writes to Keychain via `TokenClient` and re-attempts the app-open sequence.

---

## 14. Caching & offline (D23)

- **Daily brief** is stable for the Europe/Sofia day: cache hit on re-open, served offline. Not
  auto-regenerated on open — only sync + serve cache (PRD §8.2).
- **Weekly plan** cached per ISO week; regenerated on the first open of a new week.
- **Sync failure blocks a *fresh* brief** (stale data → wrong brief). A same-day cached brief still
  shows; a missing one with sync failure → the block-and-retry state.
- **Empty states** are first-class: `intakeYesterday = null`, `nutrition.lastWeek = null`,
  `budgets.longRunKm = null`, partial HK grants (PRD §8.5).

---

## 15. Concurrency

- Swift 6.3 strict concurrency (D2). Dependency clients are `Sendable` structs of `@Sendable`
  closures. Reducers are value types; effects are structured `async` work with cancellation IDs.
- HealthKit and Keychain calls are isolated behind their clients so strict-concurrency friction is
  contained to the `*Live` targets.

---

## 16. Testing strategy

| Layer | How | Tooling |
|---|---|---|
| Reducers / components | **Exhaustive `TestStore`** (D18) — every state mutation + effect asserted | TCA TestStore |
| Repository live | mapping (DTO↔domain↔record), cache policy, error mapping | XCTest + stubbed client deps |
| Wire decoding | decode `SampleData` JSON → DTO; round-trip key checks | XCTest |
| Views | **Snapshot** (D16): light + dark, single reference device, states {loading, ready-fresh, ready-cached, forced-REST, error, empty} | swift-snapshot-testing |
| Fixtures | one source of truth for samples (D17) | `SampleData` target |

Previews and tests draw from `SampleData` + each client's `previewValue`/`testValue`, so nothing
pulls a live dependency.

---

## 17. Open decisions (deferred — recommendations below)

### 17.1 (OPEN-1) Cross-feature shared state

How do auth status, profile constants (zones/baselines used everywhere for display), and the
same-day brief reach multiple features?

- **Recommended:** *Repositories only; reactive via `AsyncStream`.* No `@Shared` for app state.
  Features call repositories; live updates come from repository-exposed `AsyncStream`s (GRDB
  `ValueObservation` under the hood). Honors the "reducer accesses only repositories" rule strictly.
  Auth is already covered by `TokenClient` + the 401 stream, so little is lost.
- **Alternative:** `@Shared` for profile constants only (rarely change, read everywhere) — a small,
  pragmatic exception while everything dynamic stays in repositories.
- **Impact:** local; does not block other layers. Resolve before building the first feature that
  needs cross-feature reads (likely `DesignSystem` zone display via `ProfileRepository`).

### 17.2 (OPEN-2) Client-side time / ISO-week handling

How does the app decide it's a "new ISO week" (to trigger the weekly brief) and label dates?

- **Recommended:** *Local compute with a pinned Europe/Sofia calendar dependency.* A
  `Calendar`/`TimeZone` dependency pinned to Europe/Sofia computes the current ISO week and labels
  dates. Matches the server frame, works offline, and is deterministic in tests via
  `@Dependency(\.date)`/`(\.calendar)`.
- **Alternatives:** always fetch weekly and let the server dedupe; or trust server-returned period
  fields only (learn "new week" only after a request).
- **Impact:** affects `CoachCore` (the calendar dependency) and the §11 orchestration's step 4.

---

## 18. Third-party dependencies

| Package | Use |
|---|---|
| pointfreeco/swift-composable-architecture | TCA: reducers, effects, navigation, `TestStore`. Bundles swift-dependencies, CasePaths, IdentifiedCollections. |
| pointfreeco/sharing-grdb (SharingGRDB) | GRDB integration; reactive observation. (`@Shared` usage gated on OPEN-1.) |
| groue/GRDB.swift | SQLite persistence (transitive via SharingGRDB; pinned directly if needed). |
| pointfreeco/swift-snapshot-testing | View snapshot tests. |
| pointfreeco/swift-tagged | (Optional) type-safe IDs in `CoachCore`. |

Tooling (not linked into the app): **SwiftFormat**, **SwiftLint** (D24).

---

*Source of truth for the wire contract is `docs/architecture/openapi.yaml` (OpenAPI 3.1). This
document tracks the iOS client architecture; the two open decisions in §17 are the only unresolved
items.*
