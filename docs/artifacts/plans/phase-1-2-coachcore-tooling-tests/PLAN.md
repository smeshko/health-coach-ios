# Plan: Phase 1.2 — CoachCore, tooling & test harness

Status: ready
Risk: medium
Epic: 01 — Foundation & tooling ([epic](../../epics/01-foundation.md))
Phase: 1.2 — CoachCore + tooling + test harness
Created: 2026-06-06

## Goal

Add the `CoachCore` foundation target (Europe/Sofia calendar/date dependency, `Tagged` ID
infrastructure, shared extensions), the SwiftFormat + SwiftLint toolchain with a documented run
command, and the shared TestStore + snapshot-testing harness — so every later epic builds on a
deterministic date frame, a linted codebase, and ready-to-use test conventions.

**Prerequisite:** Phase 1.1 must be merged (the `CoachKit` package, `AppFeature`, and the `CoachApp`
app target must already exist). See [`../phase-1-1-spm-app-skeleton/PLAN.md`](../phase-1-1-spm-app-skeleton/PLAN.md).

## Scope

- A `CoachCore` library target:
  - **Europe/Sofia calendar/date dependency** — a `Calendar.europeSofia` / `TimeZone.europeSofia`
    (ISO-8601 calendar, Monday start, min-4-days-in-first-week) plus ISO-week / date-label helpers
    that read swift-dependencies `@Dependency(\.calendar)` and `@Dependency(\.date)`, and a documented
    composition-root override that pins those dependencies to Europe/Sofia.
  - **`Tagged` ID infrastructure** — add the `swift-tagged` dependency and the ID-type convention
    (a representative `Tagged`-based ID + namespace); concrete model IDs follow with the models in
    Epic 02.
  - **Shared extensions/utilities** — the epic's "shared extensions/utilities" item is satisfied in 1.2
    by the calendar/ISO-week helpers and the `Tagged` ID convention above; no other free-standing
    extensions are added speculatively (YAGNI). This is intentional, not an unmet acceptance item.
- **SwiftFormat + SwiftLint**: `.swiftformat` and `.swiftlint.yml` config at the repo root, a
  documented run command (a `Makefile` with `format` / `lint` targets) plus an optional git
  pre-commit hook, and a short README/CONTRIBUTING note covering tool install + invocation.
- **Shared test harness** exposed for later test targets:
  - `swift-snapshot-testing` dependency + a `CoachTestSupport` helper target wrapping the D16 snapshot
    convention (light + dark, single reference device).
  - A sample **exhaustive `TestStore`** test (against `AppFeature`) and a sample **snapshot** test
    (against `AppView`), proving the harness is wired.
  - A `CoachCoreTests` test asserting ISO-week math in Europe/Sofia with the calendar/date
    dependencies overridden (deterministic).

## Out of Scope

- Phase 1.1 work (the package, `AppFeature`, the app target) — already done.
- Any DTO / domain / persistence model (Epic 02); concrete `Tagged` model IDs land there. 1.2 only
  establishes the `Tagged` convention.
- The `SampleData` fixtures target (Epic-wide; D17) and `DesignSystem` — later epics. The harness here
  uses inline/minimal fixtures, not `SampleData`.
- CI (deferred per ARCHITECTURE D24); the lint/format/test commands are run locally / in a git hook.
- Accessibility-variant snapshot matrix (explicitly out per D16) — light + dark on one device only.

## Research Summary

Detailed findings in [`RESEARCH.md`](./RESEARCH.md). The essentials:

- **OPEN-2 (ARCHITECTURE §17.2) is resolved here**: local compute with a pinned **Europe/Sofia**
  calendar dependency, deterministic in tests via `@Dependency(\.date)` / `@Dependency(\.calendar)`.
  CoachCore builds on the **built-in** swift-dependencies keys rather than a bespoke client (see
  [`DECISIONS.md`](./DECISIONS.md)).
- **Dependencies** (ARCHITECTURE §18): add `swift-dependencies` and `swift-tagged` as **direct**
  package dependencies, plus `swift-snapshot-testing` (test only). `Dependencies` is **not** a product
  of `swift-composable-architecture` (TCA exposes only the `ComposableArchitecture` product), so
  CoachCore must depend on `swift-dependencies` directly rather than transitively via TCA — and must
  **not** depend on `ComposableArchitecture` to reach `@Dependency`, which would pull all of TCA into
  the bottom layer (validation round-1 #1/#2, verified in SPM). SPM unifies the direct
  `swift-dependencies` with the version TCA already pins.
- **Testing conventions** (ARCHITECTURE §14/§16, D16/D18): exhaustive `TestStore` by default; snapshot
  = light + dark, single reference device, no a11y matrix. These conventions are *seeded* here and the
  `CoachTestSupport` helper makes them reusable.
- **XCTest-linking caution**: `swift-snapshot-testing` (and the `CoachTestSupport` helper) link XCTest,
  so the helper target must be depended on **only** by test targets — never by the app or a shipping
  library — or the app build breaks.

## Decisions

See [`DECISIONS.md`](./DECISIONS.md) for (1) the Europe/Sofia calendar-dependency approach and (2) the
lint/format run mechanism. Other decisions:

- **Shared snapshot helper as a `CoachTestSupport` target** — a small library target (linking
  `swift-snapshot-testing`) holding the light+dark / reference-device wrapper, depended on only by test
  targets. Satisfies "exposed for later test targets" without duplicating the config per target.
- **SwiftFormat = nicklockwood/SwiftFormat, SwiftLint = realm/SwiftLint** (ARCHITECTURE D24/§15 name
  "SwiftFormat"), installed via Homebrew; versions noted in the README so runs are reproducible.
- **`Tagged` infra is thin in 1.2** — establish the dependency + the ID-type pattern only; concrete
  IDs (athlete, brief, …) arrive with the models in Epic 02 to avoid speculative types.

## Risks

- **`swift-dependencies` `\.calendar` / `\.date` default values are not Europe/Sofia** — forgetting to
  pin them yields wrong ISO-week math in production — _mitigation_: document + provide the
  composition-root override; the `CoachCoreTests` test explicitly overrides and asserts ISO-week
  behaviour across a year boundary.
- **XCTest linked into a non-test target** — if `CoachTestSupport` is depended on by the app/library,
  the app fails to build — _mitigation_: only test targets depend on it; verify `swift build` (app
  path) stays clean.
- **iOS-only snapshot code breaks the host `swift build`/`swift test`** — `swift build`/`swift test`
  compile every target for the macOS host (even with `--filter`); `CoachTestSupport` and
  `AppFeatureSnapshotTests` reference iOS-only `UIKit`/`ViewImageConfig` APIs — _mitigation_: wrap all
  such code in `#if canImport(UIKit)` so those targets compile to an empty module on the host
  (validation round-2 #A); the manifest's `.macOS` platform (Phase 1.1) covers the rest of the host
  build. Verify `swift build` + `swift test` are green on the host with the snapshot target present.
- **Snapshot tests are environment-sensitive** (device/OS rendering) — references recorded on one
  machine can fail on another — _mitigation_: pin a single reference device (D16); commit references
  generated on the iOS 26 simulator; document the record/verify workflow.
- **SwiftLint/SwiftFormat disagreeing or over-aggressive rules churn the codebase** — _mitigation_:
  start from a conservative, documented rule set; ensure `make format` then `make lint` is clean on
  the existing 1.1 + 1.2 sources before checking off.
- **Toolchain drift** (different SwiftFormat/SwiftLint versions format differently) — _mitigation_:
  pin/record tool versions in the README; revisit when CI lands (D24).

## Acceptance Criteria

- [ ] `CoachCore` builds and exposes a Europe/Sofia calendar/date dependency with a deterministic test
      value (overridable via `@Dependency`).
- [ ] SwiftFormat and SwiftLint run **clean** via the documented command (`make lint` / `make format`).
- [ ] A sample snapshot test **and** a sample `TestStore` test both pass, proving the harness is wired.
- [ ] A `CoachCoreTests` test overrides the calendar dependency and asserts ISO-week math resolves in
      Europe/Sofia (the epic's stated validation).

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [ ] TASK-001: Add CoachCore target with Europe/Sofia calendar dependency and Tagged IDs
- [ ] TASK-002: Add SwiftFormat and SwiftLint config with a documented run command (depends on TASK-001)
- [ ] TASK-003: Wire the TestStore and snapshot-testing harness with sample tests (depends on TASK-002)
- [ ] TASK-004: Final Validation
