# Decisions — Phase 1.2

Two decisions weighed ≥2 real options and are recorded here.

---

## 1. Europe/Sofia calendar/date dependency: built-in keys vs bespoke client

Date: 2026-06-06

### Options Considered

1. **Built-in swift-dependencies keys (`\.calendar`, `\.date`, `\.timeZone`) + a Europe/Sofia
   constant + CoachCore helpers.** CoachCore exposes `Calendar.europeSofia` / `TimeZone.europeSofia`
   and ISO-week/date-label helpers that read `@Dependency(\.calendar)` / `@Dependency(\.date)`. The
   composition root pins `$0.calendar`/`$0.timeZone` to Europe/Sofia; tests override the same keys for
   determinism.
2. **A bespoke `CalendarClient` dependency** (a new `@DependencyClient` struct with `liveValue` =
   Europe/Sofia and a deterministic `testValue`) that owns all date math.

### Dependencies

- ARCHITECTURE §17.2 (OPEN-2) recommends "local compute with a pinned Europe/Sofia calendar
  dependency … deterministic in tests via `@Dependency(\.date)`/`(\.calendar)`" — it explicitly names
  the **built-in** keys.
- The built-in keys live in `swift-dependencies`. **It is NOT reachable as a product of TCA** — TCA
  exposes only the `ComposableArchitecture` product (validation round-1 #1, verified in SPM). So this
  option requires adding `pointfreeco/swift-dependencies` as a **direct** package dependency (SPM
  unifies it with the version TCA already pins). CoachCore must **not** reach `@Dependency` by depending
  on `ComposableArchitecture`, which would pull all of TCA into the bottom-of-graph target (round-1 #2).

### Selected Option

**Option 1 — built-in keys + Europe/Sofia constants + CoachCore helpers.**

### Rationale

- Matches §17.2's wording and the idiomatic swift-dependencies pattern; reviewers/contributors already
  know `@Dependency(\.calendar)`.
- Minimal surface: one small, well-known dependency (`swift-dependencies` — declared **directly** here,
  though TCA also pulls it transitively) and no bespoke client to maintain; the override is one block at
  the composition root, and tests override the exact same keys.
- The acceptance criterion ("exposes a Europe/Sofia calendar/date dependency … overridable via
  `@Dependency`") is met directly by the standard keys + the documented Europe/Sofia override.

### Rejected Options

- **Bespoke `CalendarClient`** — rejected: more surface to build/maintain, diverges from §17.2, and
  re-implements what `\.calendar`/`\.date` already provide. (Reconsider only if date logic grows
  enough to warrant a dedicated seam.)

---

## 2. SwiftFormat/SwiftLint run mechanism: Makefile vs Xcode build phase vs git hook

Date: 2026-06-06

### Options Considered

1. **`Makefile` targets (`make format` / `make lint`)** + an *optional* git pre-commit hook, with
   config files (`.swiftformat`, `.swiftlint.yml`) at the repo root and a README note.
2. **Xcode "Run Script" build phase** that lints/formats on every app build.
3. **Mandatory git pre-commit hook** as the only entry point.

### Dependencies

- ARCHITECTURE D24/§15: "SwiftFormat + SwiftLint + `git init`; CI deferred" — wants linting from day
  one but no CI yet.
- The build is pure-SPM-first (D3); `swift build` / `swift test` happen without Xcode, so build-phase
  linting would not run on the package's primary build path.
- The epic asks for "a documented run command (build phase or git hook)."

### Selected Option

**Option 1 — `Makefile` targets + optional pre-commit hook.**

### Rationale

- A `Makefile` gives one discoverable, CI-portable command that works regardless of whether the build
  goes through `swift` or Xcode — and drops straight into CI later (D24) with no rework.
- An *optional* pre-commit hook offers the "automated" path the epic mentions without forcing it on a
  single-developer repo or blocking commits during spikes.
- Keeps lint cost out of every incremental app build (Option 2's downside) and avoids coupling linting
  to Xcode when the canonical build is SPM.

### Rejected Options

- **Xcode build phase** — rejected: doesn't run on the `swift build`/`swift test` path, adds latency to
  every Xcode build, and ties tooling to the thin app target that D3 wants to keep minimal.
- **Mandatory git hook only** — rejected: hooks aren't version-controlled by default and a single hard
  gate is heavy for a solo repo; offered as opt-in instead.
