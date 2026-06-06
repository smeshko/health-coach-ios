# Adversarial Validation — Round 2

**Run:** 2026-06-06
**Plan:** phase-1-2-coachcore-tooling-tests
**Status at start:** ready
**Prior rounds in scope:** validation/round-1.md
**Review engine:** Independent adversarial **subagent** (Codex working-tree path inapplicable — pre-git
project; documented fallback). Verified empirically on Xcode 26.4 / Swift 6.3 + TCA 1.25.5 /
swift-snapshot-testing 1.19.2.

## Codex output

<!-- Independent adversarial subagent output, verbatim. -->

## Round-1 applies: verification
- **#1 — direct `swift-dependencies` dep:** reconciled in all four files (TASK-001, RESEARCH, DECISIONS, PLAN); grep-clean of the false "comes from TCA" claim. Confirmed against real TCA 1.25.5 that `Dependencies` is `.product(name:"Dependencies", package:"swift-dependencies")` and TCA exposes only `ComposableArchitecture`. Landed correctly.
- **#2 — don't reach `@Dependency` via `ComposableArchitecture`:** present in TASK-001/RESEARCH/DECISIONS. Confirmed TCA `@_exported import Dependencies`, so the trap is real and the guard warranted. Landed correctly.
- **#3 — split into `AppFeatureTests` + `AppFeatureSnapshotTests`:** structurally applied (correct per-target deps; consistent Files/Acceptance/Steps) BUT incomplete — see #A.
- **#4 — two run-paths:** thorough (RESEARCH/TASK-003/TASK-004); "or xcodebuild" ambiguity gone. Landed (caveat: host path not green until #A).
- **#6 — "shared extensions" YAGNI:** explicit in PLAN. Landed.
- **#7 — `withSnapshotTesting(record: .all)`:** present; confirmed `isRecording` deprecated in 1.19.2. Landed.
- **#8 — TestStore no longer presupposes `.onAppear`:** reworded. Landed.
- **#5 (defer) / #9 (reject):** agree; ownership clean (TASK-001 → CoachCore/CoachCoreTests; TASK-003 → CoachTestSupport/AppFeatureTests/AppFeatureSnapshotTests).

## NEW findings

**#A — The split is necessary but NOT sufficient: an unguarded `CoachTestSupport` (and `AppFeatureSnapshotTests`) re-introduces the host-build break at the library level.**
- Severity: **high**
- Evidence (reproduced on Swift 6.3 / Xcode 26.4): `CoachTestSupport` is a plain library linking `SnapshotTesting`; its "single reference device" wrapper must reference `ViewImageConfig` / `.image(layout: .device(config:))`, which in swift-snapshot-testing 1.19.2 are wrapped in `#if os(iOS) || os(tvOS)` and do not exist on macOS — and the wrapper will `import UIKit`. An SPM library target with unguarded `import UIKit` / iOS-only symbols **fails BOTH `swift build` AND `swift test` on the host** (`no such module 'UIKit'`). Also reproduced: `swift test --filter GoodTests` still compiles the snapshot target and aborts the whole run on its compile error. The plan nowhere mentions `#if canImport(UIKit)` guards; "AppFeatureTests has no snapshot code" addresses only one of three host-compiled targets.
- Verdict: **apply**
- What to change: require all snapshot/UIKit code in `CoachTestSupport` + `AppFeatureSnapshotTests` to be `#if canImport(UIKit)`-guarded (compile to empty on host); add an acceptance line that host `swift build`/`swift test` succeed with those targets present; extend the RESEARCH §4.6 note.

**#B — No version constraint (`from:`) on any of the three new direct package dependencies.**
- Severity: med
- Evidence: TASK-001/TASK-003 add `swift-dependencies`, `swift-tagged`, `swift-snapshot-testing` with no `from:`/range — an SPM `.package(url:)` requires one. On unification: TCA 1.25.5 pins `swift-dependencies` `from: "1.4.0"` (a lower bound, **not** `exact`), so an unconstrained-but-`from:`-pinned direct dep resolves to the highest version satisfying both — **no conflict**.
- Verdict: **apply**
- What to change: add `from:` to all three (`swift-dependencies` `from: "1.4.0"`, others current majors); note TCA's pin is a range so unification is conflict-free.

**#C — `AppFeatureSnapshotTests` needs a shared scheme (+ possibly a test host) for `xcodebuild test`.**
- Severity: low-med
- Evidence: an SPM test target runs under `xcodebuild` only if surfaced in a shared scheme with a tested target; the plan never states the snapshot target is reachable from the `CoachApp` scheme. Device-config rendering may need a host application.
- Verdict: **apply** (cheap clarification)
- What to change: state the snapshot target is reachable from a shared scheme; note the snapshot strategy choice accounts for whether a test host is required.

**#D — `swift build` "no warnings" AC interacts with #A** — folded into #A (unguarded library makes `swift build` *fail*, not warn; the `#if canImport(UIKit)` guard fixes it).

**Mapping checks — all OK:** PLAN task-list line for TASK-003 is generic and doesn't contradict the split; TASK-004 enumerates both targets + both run-paths; PLAN acceptance maps; no dependency cycle or double-ownership (`CoachCore` → {swift-dependencies, swift-tagged}; `CoachTestSupport` → SnapshotTesting, consumed only by `AppFeatureSnapshotTests`).

**Net assessment:** Round-1 applies all landed and are factually correct (verified #1/#2 vs TCA 1.25.5, #7 vs snapshot-testing 1.19.2), but the #3 fix is **incomplete in a high-severity way**: splitting the snapshot test into its own target doesn't make that target or the new `CoachTestSupport` host-compilable, so host `swift build`/`swift test` still break unless the iOS-only code is `#if canImport(UIKit)`-guarded (reproduced). Fix #A (load-bearing) and #B (add `from:`; unification with TCA's `from: "1.4.0"` is conflict-free); #C is a cheap scheme clarification.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Round-1 #1 (direct swift-dependencies) reconciled everywhere | n/a | reject | Verified landed + correct | — |
| 2 | Round-1 #2 (not via ComposableArchitecture) present | n/a | reject | Verified landed + correct | — |
| 3 | Round-1 #3 split applied but incomplete | high | apply | Addressed by #A (the guard is the missing half) | (via #A) |
| 4 | Round-1 #4 run-paths thorough | n/a | reject | Verified landed | — |
| 6 | Round-1 #6 YAGNI explicit | n/a | reject | Verified landed | — |
| 7 | Round-1 #7 record API | n/a | reject | Verified landed + correct vs 1.19.2 | — |
| 8 | Round-1 #8 onAppear hedge | n/a | reject | Verified landed | — |
| A | **NEW:** unguarded `CoachTestSupport`/snapshot target break host `swift build`/`swift test` | high | apply | Reproduced; require `#if canImport(UIKit)` guards | TASK-003, PLAN.md:Risks, RESEARCH.md |
| B | **NEW:** missing `from:` version constraints on 3 new deps | med | apply | SPM requires it; add `from:` (unification conflict-free) | TASK-001, TASK-003, RESEARCH.md |
| C | **NEW:** snapshot target needs a shared scheme / test-host note | low-med | apply | Prevents "xcodebuild finds no tests" | TASK-003 |
| D | `swift build` no-warnings interacts with #A | low | apply | Folded into #A | (via #A) |
| 5 | Round-1 #5 (XCTest-in-library) | low | defer | Works + risk called out; structural enforcement out of scope | — |
| 9 | Shared Package.swift edits serialize cleanly | low | reject | Confirmation | — |
