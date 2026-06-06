# Research: Phase 1.2 — CoachCore, tooling & test harness

Curated findings only — no raw conversation transcripts.

## Key Files & Directories

- `docs/architecture/ARCHITECTURE.md` — binding references: §4.1 (`CoachCore` responsibility), §14/§16
  (testing strategy), §15 (concurrency + tooling), §17.2 (OPEN-2: client-side time / ISO week), §18
  (dependency inventory), §2 D16/D17/D18/D24.
- `docs/artifacts/epics/01-foundation.md` — Phase 1.2 "What to build" / "Acceptance criteria" /
  "Validation", satisfied verbatim by this plan.
- `Package.swift` (created in 1.1) — this phase **edits** it to add the `CoachCore`, `CoachTestSupport`,
  and test targets and the `swift-tagged` / `swift-snapshot-testing` dependencies.
- `Sources/AppFeature/` (created in 1.1) — the reducer/view the sample `TestStore` + snapshot tests
  exercise.

## Architecture Facts

- **§4.1 — `CoachCore`.** lib, depends on "— (maybe Tagged)"; responsibility: "Tagged ID types, the
  calendar/date dependency, shared extensions, small utilities." The epic upgrades `Tagged` from
  optional to required.
- **§17.2 (OPEN-2) — recommended resolution:** *local compute with a pinned Europe/Sofia calendar
  dependency.* A `Calendar`/`TimeZone` pinned to Europe/Sofia computes the current ISO week and labels
  dates; deterministic in tests via `@Dependency(\.date)` / `@Dependency(\.calendar)`. "Affects
  `CoachCore` (the calendar dependency) and the §11 orchestration's step 4." → This phase implements
  that recommendation.
- **§11 step 4** — the app triggers the weekly brief when "calendar says new ISO week (OPEN-2)"; the
  ISO-week helper built here is what later powers that decision (Epic 07/08).
- **D16 — snapshot testing:** swift-snapshot-testing, **light + dark, single reference device**,
  multiple states; **no accessibility-variant matrix in v1**. The `CoachTestSupport` helper encodes
  exactly this.
- **D18 — reducer tests:** exhaustive `TestStore` by default. The sample test demonstrates the
  exhaustive style.
- **§4.6 split + run paths (validation round-1 #3/#4, verified in SPM):** the architecture defines
  **separate** `*Tests` (reducer/logic) and `*SnapshotTests` (view) targets — and this is structural,
  not cosmetic. SwiftUI image snapshots use the iOS/UIKit `ViewImageConfig` / `.device` API, which
  **does not compile on the macOS host**; co-locating a snapshot test with a logic test in one target
  makes the *whole* target fail to compile under `swift test` (even `--filter` can't bypass a compile
  error). So: logic tests (`CoachCoreTests`, `AppFeatureTests`) run via `swift test` on the host;
  snapshot tests (`AppFeatureSnapshotTests`) run via `xcodebuild test` against an iOS 26 simulator.
  - **The split alone is not enough (validation round-2 #A, verified):** `swift build` / `swift test`
    compile *every* library and test target in the graph for the macOS host (even `swift test --filter`
    compiles all targets first). So `CoachTestSupport` (which references the iOS-only `ViewImageConfig` /
    `.device(config:)` API and `import UIKit`) and `AppFeatureSnapshotTests` must be wrapped in
    `#if canImport(UIKit)` to compile to an **empty module on the host** — otherwise the host build/test
    fail with `no such module 'UIKit'`. `AppFeatureSnapshotTests` is also surfaced via a **shared
    scheme** so `xcodebuild test` can find it (round-2 #C).
- **Package platforms include `.macOS` (from Phase 1.1, round-2 #12):** the `CoachKit` manifest declares
  `[.iOS(.v26), .macOS(.v14)]`. The `.macOS` line is what lets `swift build` / `swift test` (host) and
  the host-compilable `CoachTestSupport`/`CoachCoreTests`/`AppFeatureTests` compile at all (TCA +
  swift-snapshot-testing require macOS 13+). Phase 1.2's new targets inherit these platforms.
- **Dependency version constraints (validation round-2 #B, verified):** a bare `.package(url:)` is
  invalid SPM. Add `swift-dependencies` `from: "1.4.0"` (matches TCA's own lower bound — a range, not
  `exact` — so SPM unifies with no conflict), `swift-tagged` `from: "0.10.0"` (pre-1.0), and
  `swift-snapshot-testing` `from: "1.17.0"` (resolves to current 1.19.x).
- **D24 / §15 — tooling:** **SwiftFormat + SwiftLint + `git init`; CI deferred** until a remote
  exists. "SwiftFormat" = nicklockwood/SwiftFormat (not apple/swift-format).
- **§15 — concurrency:** Swift 6.3 strict concurrency (already the default from the 1.1 tools-version);
  `CoachCore` is a value-type/utility target, so concurrency friction is minimal.
- **§18 dependencies relevant here:** `pointfreeco/swift-dependencies` (for `@Dependency(\.calendar)` /
  `(\.date)`), `pointfreeco/swift-tagged` (type-safe IDs in `CoachCore`), and
  `pointfreeco/swift-snapshot-testing` (view snapshot tests).
  - **Correction (validation round-1 #1, verified in SPM):** `Dependencies` is **not** a product of
    `swift-composable-architecture` — TCA exposes only the `ComposableArchitecture` product, so
    `.product(name: "Dependencies", package: "swift-composable-architecture")` fails to resolve. Add
    `swift-dependencies` as a **direct** package dependency and use
    `.product(name: "Dependencies", package: "swift-dependencies")`. SPM unifies it with the version
    TCA already pins (no conflict). Do **not** reach `@Dependency` via `ComposableArchitecture` — that
    pulls all of TCA into the bottom-of-graph `CoachCore` (round-1 #2).

## Constraints

- **`CoachCore` must not depend on TCA features or models** — it is the bottom of the graph (§3/§4).
  It may use `swift-dependencies` (for `@Dependency`) and `swift-tagged`, nothing higher.
- **XCTest linkage**: `swift-snapshot-testing` imports XCTest; any target linking it (incl.
  `CoachTestSupport`) must be depended on **only** by test targets, never by the app or a shipping
  library, or the app build breaks.
- **Determinism**: tests must override `\.calendar` (→ Europe/Sofia) and `\.date` (→ a fixed instant)
  so ISO-week assertions are stable regardless of the host machine's locale/timezone.
- **No `SampleData` target yet** (D17 — arrives later); the sample tests use inline/minimal fixtures.

## Useful Commands

```bash
# Tooling install (document the resolved versions in the README)
brew install swiftformat swiftlint

# Documented run command (added by this phase)
make format      # swiftformat .
make lint        # swiftlint lint --strict

# Tests run on TWO distinct paths (not interchangeable — see Architecture Facts):
#   1. Host logic tests — CoachCoreTests + AppFeatureTests (TestStore) run on the macOS host:
swift test
#   2. iOS snapshot tests — AppFeatureSnapshotTests (SwiftUI image snapshots are UIKit-only;
#      they cannot compile/run under `swift test`) need a simulator, via the ios-build skill:
#      xcodebuild test -scheme CoachApp -destination 'platform=iOS Simulator,name=<iPhone>,OS=26.0'

# Re-record snapshot references when intentionally changing a view (swift-snapshot-testing ≥ 1.19):
#   wrap in `withSnapshotTesting(record: .all) { ... }` (or pass `record:` to assertSnapshot),
#   run once, then revert. NOTE: the old `isRecording = true` global is deprecated.
```

## Uncertainty

- **Europe/Sofia calendar construction** — use `Calendar(identifier: .iso8601)` with
  `timeZone = TimeZone(identifier: "Europe/Sofia")!`; the ISO-8601 calendar already implies Monday
  `firstWeekday` and `minimumDaysInFirstWeek = 4`. Confirm with the year-boundary test (e.g.
  2025-12-29 → ISO week 1 of 2026; the implementer verifies the exact expected `(year, week)`).
- **Bespoke calendar dependency vs built-in keys** — resolved to built-in `\.calendar`/`\.date` +
  Europe/Sofia constants + helpers (see DECISIONS.md), matching §17.2's wording.
- **Lint/format run mechanism** — resolved to a `Makefile` + optional git pre-commit hook (see
  DECISIONS.md); an Xcode build phase was rejected to keep the build pure-SPM-friendly and avoid
  per-build lint cost.
- **Exact SwiftFormat/SwiftLint versions** — pinned by recording the installed versions in the README;
  revisit when CI lands and can pin them centrally (D24).

## References

- ARCHITECTURE.md §4.1, §11 (step 4), §14, §15, §16, §17.2, §18; D16, D17, D18, D24.
- Epic 01 — Foundation & tooling, Phase 1.2 (What to build / Acceptance criteria / Validation).
- pointfreeco: swift-dependencies (`\.calendar`, `\.date`), swift-tagged, swift-snapshot-testing.
