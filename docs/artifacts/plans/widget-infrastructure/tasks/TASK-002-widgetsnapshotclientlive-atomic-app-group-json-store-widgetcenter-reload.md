# TASK-002: WidgetSnapshotClientLive: atomic App-Group JSON store + WidgetCenter reload

Depends on: TASK-001
Suggested commit: `feat(widgets): WidgetSnapshotClientLive — atomic App Group JSON store + timeline reload`

## Goal

Implement the live side: an atomic JSON store over the App Group container with load-merge-write
semantics that preserve the sections this phase doesn't write, `WidgetCenter.reloadAllTimelines()` after
each write, and the `DependencyKey` `liveValue` — all failures logged and swallowed.

## Files

- `Sources/Clients/WidgetSnapshot/Live/WidgetSnapshotStore.swift` — new: the file store, `public` (the
  merge/read machinery, base-URL-injectable for host tests):
  - `public struct WidgetSnapshotStore: Sendable` holding the snapshot `fileURL` (file name
    `widget-snapshot.json`), `public init(directoryURL: URL)`.
  - `public static let appGroupID = "group.com.smeshko.CoachApp"` and
    `public static func appGroupStore() -> WidgetSnapshotStore?` via
    `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` (nil off-entitlement —
    e.g. the macOS host — never a crash).
  - `func read() -> WidgetSnapshot?` — nil on missing file OR undecodable bytes (a corrupt mirror is "no
    snapshot", the Phase 19.2 degrade-don't-fail convention).
  - `func write(_ snapshot: WidgetSnapshot) throws` — `WidgetSnapshotCoding.makeEncoder()` +
    `data.write(to:options:.atomic)` (atomic replace: the extension never observes a torn file).
  - `func mergeDailyBrief(_ brief: DomainModels.DailyBrief)` (or an equivalent pure
    `static merge(daily:into:)` + a thin instance wrapper — pick whichever keeps the merge pure and
    directly testable): map `DailyBrief` → `WidgetDailySnapshot` (`date`, `readiness`, `safetyGate`,
    `plannedSession: brief.session`; `selectedSession` — preserve `existing?.daily?.selectedSession`
    **only when the existing daily is the SAME Sofia day as `brief.date`** (a same-day refresh keeps the
    athlete's pick; a new-day brief drops the stale prior-day selection → nil). 21.2 owns *writing*
    selectedSession, but 21.1 freezes this merge rule, so it must be day-guarded here, not carried
    unconditionally (validation round-1 #2 — reuse `WidgetDailySnapshot.isCurrent(at:calendar:)` / a
    Sofia `startOfDay` equality, NOT a raw `Date ==`); `macroFocus`, `intakeYesterday`), replace only the
    `daily` section + root `generatedAt`/`schemaVersion`, preserve `weekly` and `checkIn` verbatim.
- `Sources/Clients/WidgetSnapshot/Live/WidgetSnapshotClient+Live.swift` — new
  (LogClient+Live.swift / BriefRepositoryLive.swift are the template):
  - `extension WidgetSnapshotClient: DependencyKey { public static var liveValue: WidgetSnapshotClient }`
    — `updateDailyBrief`: resolve `appGroupStore()`; nil → one `log.notice` (App Group missing) and
    return; else merge-write, then reload timelines, then `log.info("Widget snapshot updated",
    category: .app)` with the Sofia day in metadata (the epic's "observable via log" acceptance hook).
    Write errors: `log.notice` + drop — NEVER thrown (DECISIONS D6). `read`: `appGroupStore()?.read()`.
  - `WidgetCenter.shared.reloadAllTimelines()` wrapped in `#if canImport(WidgetKit)` so the macOS host
    build compiles regardless (the HealthKitClientLive `#if canImport` precedent).
- `Sources/Clients/WidgetSnapshot/Tests/WidgetSnapshotClientLiveTests/WidgetSnapshotStoreTests.swift` —
  new (host, Swift Testing, sibling nested dir — the LogClient two-test-target layout). Tests run against
  `WidgetSnapshotStore(directoryURL:)` over a fresh temp directory (`FileManager.default.temporaryDirectory
  .appendingPathComponent(UUID().uuidString)`), never the real container.
- `Package.swift` — new target `WidgetSnapshotClientLive` (deps: WidgetSnapshotClient, DomainModels,
  CoachCore, LogClient, `.product(Dependencies)`; path `Sources/Clients/WidgetSnapshot/Live`) + new
  `.library(name: "WidgetSnapshotClientLive", ...)` product (linked by BOTH the app target (TASK-005) and
  the extension (TASK-006)); new test target `WidgetSnapshotClientLiveTests` (deps: WidgetSnapshotClient,
  WidgetSnapshotClientLive, DomainModels, SampleData, CoachCore).

## Acceptance

- [ ] Write→read round-trip over a temp dir returns the identical `WidgetSnapshot`.
- [ ] `mergeDailyBrief` into a file carrying `weekly` + `checkIn` + a **same-Sofia-day** `selectedSession`
      replaces the daily fields but preserves `weekly`, `checkIn`, and that `selectedSession` untouched
      (the no-schema-surgery guarantee 21.2/21.4/21.5 rely on).
- [ ] `mergeDailyBrief` with a NEW `brief.date` (later Sofia day) over a file whose daily carries a
      `selectedSession` drops that stale selection (`selectedSession == nil` in the result) while still
      preserving `weekly`/`checkIn` (validation round-1 #2).
- [ ] `mergeDailyBrief` with no existing file creates a daily-only snapshot.
- [ ] `read()` on a corrupt file (garbage bytes) returns nil — no throw, no crash.
- [ ] Missing store/container path degrades silently (nil-store guard covered by construction — the
      liveValue guard is code-reviewed, not host-testable).
- [ ] `swift build`, `swift test`, `make lint` all green.

Evidence: `swift test` output listing `WidgetSnapshotClientLiveTests` green.

## Steps

### RED
- [ ] Add `WidgetSnapshotStoreTests.swift` covering the acceptance list (fixture `DailyBrief` from
      SampleData or a literal; fixed dates).
- [ ] Register the Live + test targets in Package.swift.

### GREEN
- [ ] Implement `WidgetSnapshotStore` + the `liveValue` extension as specified.

### REFACTOR
- [ ] Keep the DailyBrief→WidgetDailySnapshot mapping a single pure function; house-style comments;
      `make lint`.

## Notes

- **Serialize writes (validation round-1 #3).** `Data.write(.atomic)` stops a reader seeing a torn file,
  but the read→merge→write cycle is NOT atomic: two concurrent `update*` calls can both read the same
  base and the second write silently drops the first's section. 21.1 freezes this store for later phases
  that add sibling section writers (`updateWeeklyPlan`/`updateSelectedSession`/`updateCheckIn`, each
  read-modify-writing the same file), so the whole class of lost-update is designed-in now unless the
  writes are serialized. Route the live client's read/merge/write through a SINGLE `actor` (e.g. an
  `actor WidgetSnapshotFileStore` the `liveValue` holds, or an actor the closures hop through) so all
  mutations of the file are serialized within the process. Keep the pure `merge(daily:into:)` a free
  function so it stays host-testable without the actor. The struct-vs-actor split is the implementer's
  call as long as concurrent `update*` calls cannot lose each other's sections.
- `Data.write(.atomic)` is the whole cross-process/torn-read story — no `NSFileCoordinator` (WidgetKit
  reloads re-read the file after the rename; a same-instant reader sees the previous complete file, which
  is fine for a display mirror). The app writes; the extension only reads.
- The log category for the success line is `.app` (gated, plenty for the dev-observability criterion);
  failure notices ride `.app` too — this is not network traffic, don't abuse the always-on `.http`.
