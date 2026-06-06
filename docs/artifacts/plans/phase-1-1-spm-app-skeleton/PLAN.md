# Plan: Phase 1.1 — SPM package & thin app target

Status: ready
Risk: medium
Epic: 01 — Foundation & tooling ([epic](../../epics/01-foundation.md))
Phase: 1.1 — SPM package + thin app target
Created: 2026-06-06

## Goal

Stand up the buildable skeleton — a single `CoachKit` Swift package holding an `AppFeature`
library target (placeholder TCA reducer + view) and a thin `CoachApp` `.xcodeproj` app target that
launches `AppView(store:)` — so every later epic has a package to add targets to and an app to run.

## Scope

- A root `Package.swift` (package name `CoachKit`) with `swift-tools-version: 6.3`, the `.iOS(.v26)`
  platform, the `swift-composable-architecture` dependency, and an `AppFeature` library product/target.
- An `AppFeature` library target: a placeholder `@Reducer` `AppFeature` with `@ObservableState`
  `State`, a minimal `Action`, an `EmptyReducer`-style `body`, and an `AppView: View` taking
  `StoreOf<AppFeature>`. All `public`.
- A thin `CoachApp.xcodeproj` app target whose `@main` `App` builds
  `AppView(store: Store(initialState:) { AppFeature() })` and contains no other logic; it depends on
  the root package and links the `AppFeature` product.
- `git init` plus a Swift/Xcode `.gitignore` (build products, `.swiftpm`, `xcuserdata`, `DerivedData`,
  `.DS_Store`).

## Out of Scope

- `CoachCore`, SwiftFormat/SwiftLint, and the TestStore + snapshot test harness — these are
  **Phase 1.2** (see [`../phase-1-2-coachcore-tooling-tests/PLAN.md`](../phase-1-2-coachcore-tooling-tests/PLAN.md)).
- Any DTO / domain / persistence model (Epic 02), data source or repository (Epics 03–04), or
  design-system component / feature UI beyond the placeholder (Epics 05+).
- Any unit or snapshot test target (the harness lands in 1.2); the only verification here is a clean
  `swift build` and a simulator launch.
- CI (deferred per ARCHITECTURE D24 until a remote exists).

## Research Summary

Detailed findings in [`RESEARCH.md`](./RESEARCH.md). The essentials:

- **Architecture mandates** (ARCHITECTURE.md §2 D1–D3, §3–4): iOS 26+, Swift 6.3 full strict
  concurrency, a pure-SPM `CoachKit` package + thin `.xcodeproj` app target (the isowords model),
  **zero extra project-generation tooling** (no XcodeGen/Tuist).
- **Strict concurrency is free with the toolchain**: a `swift-tools-version: 6.3` manifest defaults
  every target to the **Swift 6 language mode**, which is complete strict-concurrency checking. No
  `-strict-concurrency=complete` flag or `StrictConcurrency` experimental feature is needed (those are
  for Swift 5 mode). See RESEARCH.md → Architecture Facts.
- **The single real risk is the `.xcodeproj`** — it must be hand-created (no generator) yet correctly
  reference the local package and link `AppFeature`. Approach weighed in
  [`DECISIONS.md`](./DECISIONS.md).
- Starting state: this is **not yet a git repo** (TASK-001 creates it); no `Package.swift` exists;
  the only content under `ios/` is `docs/`.

## Decisions

See [`DECISIONS.md`](./DECISIONS.md) for the app-target creation approach (Xcode-template strip-down
vs hand-authored `pbxproj` vs project generator). Other decisions:

- **Repo layout** — `Package.swift` + `Sources/AppFeature/` at the `ios/` root; the app entry sources
  in `App/`; `CoachApp.xcodeproj` at the root referencing the package in its own directory. Mirrors
  isowords and keeps the local-package reference a same-directory path.
- **Generated Info.plist** — the app target uses `GENERATE_INFOPLIST_FILE = YES` (no checked-in
  `Info.plist`) to keep the target genuinely thin (ARCHITECTURE D3).
- **Minimal `Action`** — the placeholder reducer carries a single `onAppear` case returning `.none`
  rather than an empty `enum`, to model the real pattern and avoid empty-enum awkwardness.
- **TCA version** — depend on `swift-composable-architecture` via `from:` a recent stable (≥ 1.17),
  resolved to the latest stable at implementation time and pinned in `Package.resolved`. TCA is
  Swift-6 / strict-concurrency ready (ARCHITECTURE D2).
- **Explicit `.swiftLanguageMode(.v6)`** — set on the `AppFeature` target even though
  `swift-tools-version: 6.3` already defaults to it. It is equivalent + harmless, self-documents the
  strict-concurrency intent, and satisfies the epic's literal "strict-concurrency build settings"
  wording so ticking that acceptance box is defensible (validation round-1 #7).
- **Shared scheme + tracked `Package.resolved` (×2)** — the `CoachApp` scheme is marked Shared and the
  xcodeproj's own `Package.resolved` is committed, so the build/launch acceptance is verifiable from a
  clean clone (validation round-1 #1/#2).
- **Package platforms `[.iOS(.v26), .macOS(.v14)]`** — the `.macOS` line is required for `swift build` /
  `swift test` to compile on the host (TCA needs macOS 13+; an iOS-only `platforms` line breaks the
  host build). It governs only host build/test; the shipped app target stays iOS-only (validation
  round-2 #12, verified). Epic 02+ targets inherit these platforms.

## Risks

- **Hand-authored `.xcodeproj` is fiddly and easy to get subtly wrong** (local-package reference,
  product link, sim destination) — _mitigation_: create it from Xcode's App template, then strip
  boilerplate and add the local package + `AppFeature` product (see DECISIONS.md); verify with a
  simulator build via the `ios-build` skill before checking off TASK-003.
- **Toolchain availability** — iOS 26 SDK + Swift 6.3 require Xcode 26 and an installed iOS 26
  simulator — _mitigation_: confirm `xcodebuild -version` and `xcodebuild -showsdks` / available
  simulators at the start of TASK-002/003; the `ios-build` skill auto-detects the destination.
- **"No warnings" under strict concurrency** — an unused store binding or empty `Action` can warn —
  _mitigation_: use `let store` (not `@Bindable`) in the placeholder view and the single-case `Action`
  above; treat any warning as a TASK-002 failure.
- **Local-package reference path drift** — if the xcodeproj and `Package.swift` are placed
  inconsistently the package won't resolve — _mitigation_: the fixed layout decision above; validate
  `xcodebuild -resolvePackageDependencies` succeeds.

## Acceptance Criteria

- [ ] The `CoachApp` target builds and launches on the iOS 26 simulator, showing the placeholder
      `AppFeature` view.
- [ ] `swift build` succeeds for the package under Swift 6 strict concurrency with **no warnings**.
- [ ] The xcodeproj contains only the app entry point; `AppFeature` and all future code live in the
      package.
- [ ] The directory is a git repository with a working `.gitignore` (build artifacts untracked).

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: Bootstrap git repository and Swift/Xcode .gitignore
- [ ] TASK-002: Create CoachKit Swift package and AppFeature library target (depends on TASK-001)
- [ ] TASK-003: Add thin CoachApp .xcodeproj app target launching AppView (depends on TASK-002)
- [ ] TASK-004: Final Validation
