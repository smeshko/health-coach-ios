# TASK-003: Wire the TestStore and snapshot-testing harness with sample tests

Depends on: TASK-002
Suggested commit: `test(harness): add snapshot helper and sample TestStore + snapshot tests`

## Goal

Wire the shared test harness — `swift-snapshot-testing` + a `CoachTestSupport` helper (light + dark,
single reference device) — and prove it with a sample exhaustive `TestStore` test and a sample
snapshot test, so later test targets reuse the conventions.

## Files

- `Package.swift` — add the `swift-snapshot-testing` dependency **with a version constraint**
  (`.package(url: ".../swift-snapshot-testing", from: "1.17.0")` — a bare `.package(url:)` is invalid
  SPM; resolves to the current 1.19.x); add the `CoachTestSupport` library target (deps:
  `SnapshotTesting`); and add **two separate** test targets per ARCHITECTURE §4.6:
  - `AppFeatureTests` (logic) — deps: `AppFeature`, `ComposableArchitecture`. Runs on the **macOS
    host** via `swift test`. **No snapshot/UIKit code.**
  - `AppFeatureSnapshotTests` (view) — deps: `AppFeature`, `CoachTestSupport`, `SnapshotTesting`. Runs
    only on an **iOS 26 simulator** via `xcodebuild test`.
  > The split is mandatory, not stylistic: SwiftUI image snapshots use the iOS/UIKit
  > `ViewImageConfig` / `.device` API, which **does not compile on the macOS host** — co-locating a
  > snapshot test with the `TestStore` test would make the whole target fail to compile under
  > `swift test`, taking the logic sample down with it (validation round-1 #3, verified in SPM).
  > **The split alone is NOT sufficient** — `swift build` / `swift test` compile *every* library and
  > test target in the graph for the host (even `swift test --filter` compiles all targets before
  > running a subset). So `CoachTestSupport` and `AppFeatureSnapshotTests` must compile to an **empty
  > module on the host** via `#if canImport(UIKit)` guards, or the host `swift build` / `swift test`
  > (TASK-001 AC, TASK-004 gate) break with `no such module 'UIKit'` (validation round-2 #A, verified).
- `Sources/CoachTestSupport/SnapshotConvention.swift` (new) — a wrapper encoding the D16 convention:
  snapshot a SwiftUI view in **light + dark** on a **single reference device**. Depended on only by
  test targets. **All snapshot/UIKit code must be wrapped in `#if canImport(UIKit)`** so the target
  compiles to an empty module on the macOS host (the `.device(config:)` / `ViewImageConfig` APIs and
  `import UIKit` do not exist on macOS — see round-2 #A).
- `Tests/AppFeatureTests/AppFeatureTests.swift` (new) — an **exhaustive `TestStore`** sample
  (demonstrating the D18 convention). Logic only — no snapshot imports.
- `Tests/AppFeatureSnapshotTests/AppViewSnapshotTests.swift` (new) — a sample snapshot test of
  `AppView` via the `CoachTestSupport` helper (light + dark). **Wrap the whole body in
  `#if canImport(UIKit)`** so the target compiles to empty on the host.
- `Tests/AppFeatureSnapshotTests/__Snapshots__/` (new) — committed reference images recorded on the
  iOS 26 simulator.
- `Package.resolved` — updated with swift-snapshot-testing; committed.

## Acceptance

- [ ] A sample **exhaustive `TestStore`** test passes in `AppFeatureTests` via **`swift test`** (host).
- [ ] A sample **snapshot** test passes in `AppFeatureSnapshotTests` against committed references
      (light + dark, single reference device) via **`xcodebuild test`** on an iOS 26 simulator.
- [ ] The two test targets are separate (§4.6): `AppFeatureTests` has no snapshot/UIKit code and runs
      under `swift test`; `AppFeatureSnapshotTests` holds all snapshot code.
- [ ] `swift build` **and** `swift test` succeed on the macOS host even though `CoachTestSupport` and
      `AppFeatureSnapshotTests` exist — their iOS-only bodies compile out under `#if canImport(UIKit)`
      (no `no such module 'UIKit'`).
- [ ] `AppFeatureSnapshotTests` is reachable from a **shared scheme** so `xcodebuild test` finds it
      (the package tests are surfaced in the `CoachApp` shared scheme, or a shared scheme that includes
      the test target is added); the chosen snapshot strategy accounts for whether a test host is
      needed (round-2 #C).
- [ ] `CoachTestSupport` is depended on **only** by test targets; `swift build` (app/library path)
      stays clean (no XCTest leaking into the app).
- [ ] The harness conventions (exhaustive TestStore default; light+dark single-device snapshots; the
      two run paths) are documented briefly (in `CoachTestSupport` doc comments and/or the README).

## Steps

### RED
- [ ] Add `swift-snapshot-testing` + the **two** test targets (`AppFeatureTests`,
      `AppFeatureSnapshotTests`); author the `TestStore` test (in `AppFeatureTests`) and the `AppView`
      snapshot test (in `AppFeatureSnapshotTests`) first. The snapshot test fails on first run (no
      reference yet) — record references (see below), then it passes.

### GREEN
- [ ] Add the `CoachTestSupport` target with the light+dark / single-reference-device snapshot wrapper,
      with **all** snapshot/UIKit code wrapped in `#if canImport(UIKit)` so it compiles to empty on the
      host. Verify with `swift build` (host) that the package — now including `CoachTestSupport` and the
      snapshot test target — still compiles (no `no such module 'UIKit'`).
- [ ] Implement the exhaustive `TestStore` sample in `AppFeatureTests`: build `StoreOf<AppFeature>`,
      send an existing no-op action of `AppFeature` (e.g. `.onAppear` as defined in Phase 1.1 — if 1.1's
      reducer has no such action, add a trivial one there or pick its existing one), and assert
      exhaustively that no state mutation occurs (D18). Logic only — **no** snapshot imports here.
- [ ] Implement the `AppView` snapshot sample in `AppFeatureSnapshotTests` via the helper; record
      references on the iOS 26 simulator with `withSnapshotTesting(record: .all) { … }` (the global
      `isRecording` is deprecated in swift-snapshot-testing ≥ 1.19), then revert the record flag and
      commit the references.
- [ ] Run **host** logic tests: `swift test` (covers `CoachCoreTests` + `AppFeatureTests`) — green.
- [ ] Run **simulator** snapshot tests: `xcodebuild test` on an iOS 26 simulator (via the `ios-build`
      skill) for `AppFeatureSnapshotTests` — green.

### REFACTOR
- [ ] Confirm `CoachTestSupport` is referenced only by test targets and the app/library build is clean.
- [ ] Confirm `AppFeatureTests` compiles + runs under `swift test` with no snapshot/UIKit symbols.
- [ ] Keep the helper small and reusable; ensure the convention is obvious for the next test target.

## Notes

- **XCTest linkage**: `swift-snapshot-testing` + `CoachTestSupport` link XCTest — never let the app or
  a shipping library depend on `CoachTestSupport`, or the app build breaks (see RESEARCH.md).
- **Snapshot determinism**: pin one reference device (D16); commit references recorded on the iOS 26
  simulator; document the record→verify workflow — `withSnapshotTesting(record: .all) { … }` (or the
  `record:` param on `assertSnapshot`), run once, revert (the global `isRecording` is deprecated).
- The sample tests exist to **prove the harness**, not to test product behaviour — keep them minimal.
