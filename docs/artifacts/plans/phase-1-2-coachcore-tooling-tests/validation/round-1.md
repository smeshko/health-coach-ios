# Adversarial Validation — Round 1

**Run:** 2026-06-06
**Plan:** phase-1-2-coachcore-tooling-tests
**Status at start:** ready
**Review engine:** Independent adversarial **subagent** (Codex `--scope working-tree` path inapplicable
— the project is not yet a git repo, since Epic 01 Phase 1.1 is what runs `git init`; substituting an
independent adversarial subagent is the documented fallback,
`codex-review-rate-limited-subagent-fallback`). The subagent grounded its critique by reproducing the
plan's dependency declarations and snapshot-test setup in SPM against the real toolchain (TCA pin,
swift-dependencies, swift-snapshot-testing 1.19.2).

## Codex output

<!-- Independent adversarial subagent output, verbatim. -->

## #1 — `Dependencies` is NOT a product of `swift-composable-architecture`; the package fails to build as specified
- **Severity:** high
- **Evidence:** TASK-001 "Files": "deps: `Dependencies` from swift-composable-architecture's bundled swift-dependencies". PLAN.md and RESEARCH.md both claim "`swift-dependencies` is already available transitively via TCA … no new dependency needed." Reproduced in SPM: `.product(name: "Dependencies", package: "swift-composable-architecture")` fails with `product 'Dependencies' … not found in package 'swift-composable-architecture'`. TCA exposes exactly one product: `ComposableArchitecture`.
- **Suggested verdict:** apply
- **Rationale:** The single load-bearing dependency claim of the calendar feature is factually false; TASK-001 as written cannot declare the `CoachCore` target.
- **If apply:** Declare `pointfreeco/swift-dependencies` as a **direct** package dependency and use `.product(name: "Dependencies", package: "swift-dependencies")` for `CoachCore` and `CoachCoreTests`. (Verified this builds; SPM unifies it with TCA's pinned version with no conflict.) Update TASK-001 Files, DECISIONS §1, RESEARCH, PLAN Research Summary, and `Package.resolved` ownership.

## #2 — Avoiding a direct swift-dependencies dep by importing via `ComposableArchitecture` would violate CoachCore's layering
- **Severity:** med (a trap the implementer may fall into when fixing #1)
- **Evidence:** RESEARCH.md Constraints: "`CoachCore` must not depend on TCA features or models … It may use `swift-dependencies` … nothing higher." A target depending on `ComposableArchitecture` *can* use `@Dependency(\.calendar)` (TCA `@_exported import`s Dependencies), so an implementer might "fix" #1 by depending on `ComposableArchitecture`, silently pulling all of TCA into the bottom layer.
- **Suggested verdict:** apply
- **If apply:** TASK-001: "`CoachCore` depends on `Dependencies` (from `swift-dependencies` directly) — NOT on `ComposableArchitecture`."

## #3 — Sample snapshot test in the same target as the TestStore test breaks `swift test` (and violates §4.6)
- **Severity:** high
- **Evidence:** TASK-003 places both `AppFeatureTests.swift` (TestStore) and `AppViewSnapshotTests.swift` (snapshot of `AppView`) in **one** `AppFeatureTests` target. ARCHITECTURE §4.6 defines **separate** `*Tests` and `*SnapshotTests` targets. Reproduced: a SwiftUI device-config snapshot test fails to **compile on the macOS host** (iOS `ViewImageConfig`/`.device` API absent), so the *entire* target — including the TestStore sample — is un-runnable via `swift test` (even `--filter` can't bypass compile failure).
- **Suggested verdict:** apply
- **Rationale:** As structured neither sample test runs via `swift test`, defeating the AC, and it contradicts §4.6.
- **If apply:** Split into `AppFeatureTests` (TestStore only — runs under `swift test`) and `AppFeatureSnapshotTests` (snapshot only — xcodebuild/simulator). Update PLAN task list and TASK-004.

## #4 — "Run snapshot tests via `swift test`" is overstated; the iOS-only nature needs an explicit run-path split
- **Severity:** med
- **Evidence:** RESEARCH.md/TASK-004 bundle `swift test` with "or … xcodebuild test". Logic tests run on the macOS host under `swift test`, but SwiftUI image snapshots are UIKit-only and cannot run/compile under `swift test`.
- **Suggested verdict:** apply
- **If apply:** State two run paths tied to the two targets: `swift test` for `CoachCoreTests` + `AppFeatureTests`; `xcodebuild test -destination 'platform=iOS Simulator,…'` for `AppFeatureSnapshotTests`.

## #5 — XCTest-in-a-library-target (`CoachTestSupport`) is safe here, but non-idiomatic/brittle
- **Severity:** low
- **Evidence:** Verified `swift build` of such a library succeeds on macOS + iOS-sim SDK; it only breaks if the app/a shipping lib depends on it (plan's mitigation correct). The fragility: SPM doesn't *enforce* "test targets only"; the plan relies on a manual review check.
- **Suggested verdict:** defer
- **Rationale:** The pattern works and the risk is already called out; structural enforcement is a nice-to-have.

## #6 — "Shared extensions/utilities" epic item satisfied only by YAGNI deferral — make scoping explicit
- **Severity:** low
- **Evidence:** Epic lists "shared extensions/utilities"; PLAN reduces it to "only what the above needs now". In practice 1.2 ships calendar/ISO-week helpers + the Tagged ID pattern and no free-standing extensions.
- **Suggested verdict:** defer (optional one sentence)
- **If apply:** PLAN Scope: state that the epic's "shared extensions/utilities" is satisfied by the calendar/ISO-week helpers + the Tagged ID convention; nothing else added speculatively.

## #7 — Snapshot recording guidance leads with the deprecated `isRecording` API
- **Severity:** low
- **Evidence:** RESEARCH.md: "set isRecording = true". In resolved swift-snapshot-testing 1.19.2, `isRecording` is **deprecated**; the current API is `withSnapshotTesting(record: .all) { … }`.
- **Suggested verdict:** apply
- **If apply:** RESEARCH.md + TASK-003 Notes: use `withSnapshotTesting(record: .all) { … }` (or the `record:` parameter on `assertSnapshot`).

## #8 — TestStore sample assumes a `.onAppear` action that Phase 1.1's reducer may not have
- **Severity:** low
- **Evidence:** TASK-003: "`await store.send(.onAppear)`". The epic only promises "a placeholder `@Reducer`"; nothing guarantees `.onAppear`.
- **Suggested verdict:** defer
- **If apply:** Reword to "send an existing no-op action of `AppFeature` (e.g. `.onAppear` as defined in Phase 1.1) and assert exhaustively no state mutation".

## #9 — Two tasks both edit `Package.swift` / `Package.resolved`; sequence is fine
- **Severity:** low (informational)
- **Evidence:** Target ownership is clean (TASK-001 → CoachCore + CoachCoreTests; TASK-003 → CoachTestSupport + AppFeatureTests); dependency chain serializes edits.
- **Suggested verdict:** none

## Things that hold up (verified, no change needed)
- ISO-week math: `Calendar(identifier: .iso8601)` → `firstWeekday = 2` (Monday), `minimumDaysInFirstWeek = 4`; **2025-12-29 (Monday) → ISO week-year 2026, week 1** is correct.
- `\.calendar` default is `Calendar.autoupdatingCurrent` (not Europe/Sofia); accessing it un-overridden in tests triggers `reportIssue` — the override mitigations are appropriate.
- `swift-tagged`: product `Tagged` + the `Tagged<Tag, RawValue>` pattern compile.
- Tooling names (nicklockwood SwiftFormat / realm SwiftLint), `swiftlint lint --strict`, Makefile, and the build-phase rejection are all sound.
- Task-ownership split (CoachCoreTests vs AppFeatureTests/CoachTestSupport) is clean.

**Net assessment:** The plan is NOT implementable as written — TASK-001's central dependency claim is false (`Dependencies` is not a TCA product; CoachCore needs a direct `swift-dependencies` dependency), and TASK-003 co-locates an iOS-only snapshot test with the TestStore sample in one target, which both breaks `swift test` and violates §4.6's `*Tests`/`*SnapshotTests` split. Fix #1 and #3 — they are load-bearing; the rest are verified-correct or low-severity polish.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | `Dependencies` is not a TCA product — CoachCore needs a direct `swift-dependencies` dep | high | apply | Verified false claim; plan not buildable as written | TASK-001, DECISIONS.md, RESEARCH.md, PLAN.md |
| 2 | Don't "fix" #1 by depending on `ComposableArchitecture` (layering violation) | med | apply | Pre-empts the wrong fix; preserves the dependency rule | TASK-001 |
| 3 | Snapshot test co-located with TestStore test breaks `swift test` + violates §4.6 | high | apply | Verified compile break; split into `*Tests` + `*SnapshotTests` | TASK-003, PLAN.md, TASK-004 |
| 4 | Run-path split (swift test vs xcodebuild) must be explicit, not "or" | med | apply | Removes ambiguity tied to the two targets from #3 | TASK-003, TASK-004, RESEARCH.md |
| 5 | XCTest-in-library safe but non-idiomatic/unenforced | low | defer | Works + risk already called out; structural enforcement out of scope | — |
| 6 | "Shared extensions" met via YAGNI — make explicit | low | apply | One sentence prevents a "unmet AC" misread | PLAN.md:Scope |
| 7 | `isRecording` deprecated → `withSnapshotTesting(record:)` | low | apply | Verified deprecated in 1.19.2; cheap fix | RESEARCH.md, TASK-003 |
| 8 | TestStore sample presupposes `.onAppear` from 1.1 | low | apply | Cheap robustness hedge against 1.1 drift | TASK-003 |
| 9 | Shared Package.swift edits across tasks — coherent | low | reject | Confirmation; dependency chain prevents conflict | — |
