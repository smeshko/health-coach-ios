# Epic 01 — Foundation & tooling

Status: ready for dev
Created: 2026-06-06
Depends on: none

## Overview

Establishes the buildable skeleton every later epic sits on: a single Swift package
(`CoachKit`) that will hold every feature/service as a target, a thin app target whose only job
is to launch `AppFeature`, the shared `CoachCore` utilities, and the lint/format/test
conventions. No product behaviour — purely structural, so the rest of the build proceeds
bottom-up from the models.

## Architecture references

- [ARCHITECTURE.md §3–4](../../architecture/ARCHITECTURE.md) — the layered architecture and the SPM target graph this epic stands up.
- [ARCHITECTURE.md §2 (D1–D6, D24)](../../architecture/ARCHITECTURE.md) — platform baseline (iOS 26, Swift 6.3 strict concurrency), pure-SPM + thin app target, interface/live split, tooling.
- [ARCHITECTURE.md §15–16](../../architecture/ARCHITECTURE.md) — the concurrency and testing conventions seeded here.

## Dependencies

- none

## Out of scope

- Any DTO / domain / persistence models (Epic 02).
- Any data-source client or repository (Epics 03–04).
- Any feature UI or design-system component (Epics 05+).
- CI (deferred per D24 until a remote exists).

## Phase 1.1 — SPM package + thin app target

**Plan**: [phase-1-1-spm-app-skeleton](../plans/phase-1-1-spm-app-skeleton/PLAN.md) · status: planned

**Goal**: Stand up the single Swift package, a minimal app target that launches a placeholder AppFeature, and git init — the buildable skeleton.

### What to build

- `Package.swift` with the Swift 6.3 tools version, the iOS 26 platform, strict-concurrency build settings, and the swift-composable-architecture dependency.
- An `AppFeature` library target with a placeholder `@Reducer` / `@ObservableState` reducer and an `AppView`.
- A thin `CoachApp` `.xcodeproj` app target whose `@main` `App` builds `AppView(store:)` and contains no other logic.
- `git init` plus a Swift/Xcode `.gitignore`.

### Acceptance criteria

- [ ] The `CoachApp` target builds and launches on the iOS 26 simulator, showing the placeholder AppFeature view.
- [ ] `swift build` succeeds for the package under Swift 6 strict concurrency with no warnings.
- [ ] The xcodeproj contains only the app entry point; `AppFeature` and all future code live in the package.
- [ ] The directory is a git repository with a working `.gitignore`.

### Validation

Build & run the app target on an iOS 26 simulator and confirm the placeholder renders; run `swift build` from the package root and confirm a clean strict-concurrency build.

---

## Phase 1.2 — CoachCore + tooling + test harness

**Plan**: [phase-1-2-coachcore-tooling-tests](../plans/phase-1-2-coachcore-tooling-tests/PLAN.md) · status: planned

**Goal**: Add CoachCore (Tagged IDs, Europe/Sofia calendar dependency, shared extensions), SwiftFormat/SwiftLint, and the TestStore + snapshot conventions.

### What to build

- A `CoachCore` target: `Tagged`-based ID types, the Europe/Sofia `Calendar`/`TimeZone`/date dependency (wrapping swift-dependencies `\.calendar` and `\.date`), and shared extensions/utilities.
- SwiftFormat + SwiftLint configuration and a documented run command (build phase or git hook).
- The shared test harness: TestStore conventions and the swift-snapshot-testing setup (D16 default: light+dark, single reference device) exposed for later test targets.

### Acceptance criteria

- [ ] `CoachCore` builds and exposes a Europe/Sofia calendar/date dependency with a deterministic test value (overridable via `@Dependency`).
- [ ] SwiftFormat and SwiftLint run clean via the documented command.
- [ ] A sample snapshot test and a sample TestStore test both pass, proving the harness is wired.

### Validation

Run the lint/format command (clean) and the sample tests (green); in a test, override the calendar dependency and assert ISO-week math resolves in Europe/Sofia.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [ ] Every phase merged and its acceptance criteria met
- [ ] Status row in [EPICS.md](./EPICS.md) updated to `Done`
