# TASK-001: Add CoachCore target with Europe/Sofia calendar dependency and Tagged IDs

Depends on: None (requires Phase 1.1 merged — the `CoachKit` package exists)
Suggested commit: `feat(core): add CoachCore with Europe/Sofia calendar dependency and Tagged IDs`

## Goal

Add a `CoachCore` library target exposing a Europe/Sofia calendar/date dependency (built on
`@Dependency(\.calendar)` / `@Dependency(\.date)`), ISO-week/date helpers, and the `Tagged` ID
convention, so later layers compute dates deterministically in the server's frame.

## Files

- `Package.swift` — add **two** direct dependencies **with version constraints** (a bare
  `.package(url:)` is invalid SPM): `.package(url: ".../swift-dependencies", from: "1.4.0")` and
  `.package(url: ".../swift-tagged", from: "0.10.0")` (swift-tagged is pre-1.0). Add the `CoachCore`
  library product + target. CoachCore deps:
  `.product(name: "Dependencies", package: "swift-dependencies")` and
  `.product(name: "Tagged", package: "swift-tagged")`.
  > `from: "1.4.0"` matches TCA's own lower bound on swift-dependencies (TCA pins it `from: "1.4.0"`,
  > a lower bound — **not** `exact`), so SPM unifies on the highest version satisfying both with **no
  > conflict** (validation round-2 #B, verified). Resolve to the latest stable at implementation time
  > and pin in `Package.resolved`.
  > **`Dependencies` is NOT a product of `swift-composable-architecture`** — TCA exposes only the
  > `ComposableArchitecture` product (validation round-1 #1, verified in SPM). CoachCore must take a
  > **direct** dependency on `swift-dependencies`. Do **not** depend on `ComposableArchitecture` to get
  > `@Dependency` — that would pull all of TCA into the bottom-of-graph `CoachCore` and violate the
  > dependency rule (round-1 #2). SPM unifies the direct `swift-dependencies` with the version TCA
  > already pins, with no conflict.
- `Sources/CoachCore/Calendar+EuropeSofia.swift` (new) — `public extension Calendar { static var europeSofia }`
  (`.iso8601` + `TimeZone(identifier: "Europe/Sofia")`) and `public extension TimeZone { static var europeSofia }`.
- `Sources/CoachCore/ISOWeek.swift` (new) — a `public struct ISOWeek { year, week }` + helpers that
  read `@Dependency(\.calendar)` / `@Dependency(\.date)` to compute the current ISO week and the ISO
  week for a given `Date`.
- `Sources/CoachCore/Dependencies+EuropeSofia.swift` (new) — a documented helper to pin
  `\.calendar`/`\.timeZone` to Europe/Sofia at the composition root (e.g. a `withEuropeSofia`
  `prepareDependencies`/`withDependencies` convenience).
- `Sources/CoachCore/IDs.swift` (new) — the `Tagged` ID convention (a representative
  `Tagged`-based ID + namespace/typealias pattern; concrete model IDs follow in Epic 02).
- `Tests/CoachCoreTests/CalendarTests.swift` (new) — the ISO-week determinism test (this task owns the
  `CoachCoreTests` target).
- `Package.swift` — also add the `CoachCoreTests` test target (deps: `CoachCore`,
  `.product(name: "Dependencies", package: "swift-dependencies")` for the `@Dependency` overrides).
- `Package.resolved` — updated with swift-dependencies + swift-tagged; committed.

## Acceptance

- [ ] `swift build` succeeds (no warnings) with `CoachCore` added.
- [ ] `CoachCore` exposes `Calendar.europeSofia` and ISO-week helpers driven by `@Dependency`, plus a
      documented Europe/Sofia composition-root override.
- [ ] The `Tagged` dependency is wired and the ID-type convention compiles (a representative ID type).
- [ ] `CoachCore` depends only on swift-dependencies + swift-tagged (no TCA features, no models).

## Steps

### RED
- [ ] Add the `CoachCoreTests` target (this task owns it) and author the calendar test first: override
      `\.calendar` → `.europeSofia` and `\.date` → a fixed instant, then assert the ISO week — e.g. a
      Dec/Jan-boundary date resolves to the correct `(isoYear, week)` in Europe/Sofia (verify the exact
      expected value, e.g. 2025-12-29 → week 1 of 2026). It fails before the helper exists.
  > The TCA `TestStore` sample and the snapshot harness live in TASK-003 (`AppFeatureTests` +
  > `CoachTestSupport`); `CoachCoreTests` here is a plain XCTest target (deps: `CoachCore`,
  > `Dependencies`) and is the single home of the calendar/ISO-week test.

### GREEN
- [ ] Add `swift-dependencies` and `swift-tagged` to `Package.swift` as **direct** dependencies and
      declare the `CoachCore` product + target (using the `Dependencies` product from
      `swift-dependencies`, **not** `ComposableArchitecture`).
- [ ] Implement `Calendar.europeSofia` / `TimeZone.europeSofia` (ISO-8601 calendar, Monday start,
      min-4-days-in-first-week — implied by `.iso8601`).
- [ ] Implement the ISO-week/date helpers reading `@Dependency(\.calendar)` and `@Dependency(\.date)`.
- [ ] Add the Europe/Sofia composition-root override helper + doc comment.
- [ ] Add the `Tagged` ID convention (representative type + namespace).
- [ ] Run `swift build` and the calendar test; both green.

### REFACTOR
- [ ] Keep `CoachCore` minimal — no speculative extensions (YAGNI); only what the helpers need.
- [ ] Confirm zero warnings and that nothing higher than swift-dependencies/swift-tagged is imported.

## Notes

- Use `Calendar(identifier: .iso8601)` so ISO week-of-year math is correct without manually setting
  `firstWeekday`/`minimumDaysInFirstWeek`.
- The helpers must read the **dependencies**, not a hard-coded calendar, so tests can override and the
  composition root can pin Europe/Sofia — this is what makes the test value deterministic.
- Concrete IDs (athlete, brief, week, …) are intentionally deferred to Epic 02; 1.2 only proves the
  `Tagged` pattern compiles.
