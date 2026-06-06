# Validation Summary — phase-1-2-coachcore-tooling-tests

**Rounds:** 3
**Plan status at validation:** ready
**Run on:** 2026-06-06
**Engine:** Independent adversarial subagent (Codex `--scope working-tree` path inapplicable — pre-git
project; documented fallback `codex-review-rate-limited-subagent-fallback`). The reviewer grounded
findings by reproducing the dependency declarations and snapshot setup in SPM against the real toolchain
(Xcode 26.4 / Swift 6.3; TCA 1.25.5; swift-snapshot-testing 1.19.2).

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 9        | 7       | 1        | 1        |
| 2     | 4 (new)  | 3       | 0        | 1 (folded) |
| 3     | 1 (new)  | 1 (cosmetic) | 0   | 7 (confirmations) |

## Applied

### Round 1
- `TASK-001`, `PLAN.md`, `RESEARCH.md`, `DECISIONS.md` — **[high]** `Dependencies` is **not** a product
  of TCA; declare `swift-dependencies` as a **direct** dependency and use
  `.product(name:"Dependencies", package:"swift-dependencies")` (round-1 #1, verified false claim)
- `TASK-001` — do **not** reach `@Dependency` via `ComposableArchitecture` (would pull all of TCA into
  the bottom-of-graph `CoachCore`) (round-1 #2)
- `TASK-003`, `PLAN.md`, `TASK-004` — **[high]** split the one test target into `AppFeatureTests`
  (logic, `swift test`) + `AppFeatureSnapshotTests` (snapshot, `xcodebuild`), per §4.6; co-locating an
  iOS-only snapshot test with the TestStore test breaks `swift test` (round-1 #3)
- `TASK-003`, `TASK-004`, `RESEARCH.md` — make the two run-paths explicit (host `swift test` vs
  simulator `xcodebuild test`), not an "or" (round-1 #4)
- `PLAN.md:Scope` — state the epic's "shared extensions/utilities" is satisfied by the calendar/ID
  helpers (YAGNI), not an unmet AC (round-1 #6)
- `RESEARCH.md`, `TASK-003` — use `withSnapshotTesting(record: .all)`; the global `isRecording` is
  deprecated in swift-snapshot-testing ≥ 1.19 (round-1 #7)
- `TASK-003` — TestStore sample no longer hard-presupposes a `.onAppear` action from Phase 1.1
  (round-1 #8)

### Round 2
- `TASK-003`, `PLAN.md:Risks`, `RESEARCH.md` — **[high]** the target split alone is insufficient:
  `swift build`/`swift test` compile *every* target for the host (even `--filter`), so the iOS-only
  `UIKit`/`ViewImageConfig` code in `CoachTestSupport` + `AppFeatureSnapshotTests` must be
  `#if canImport(UIKit)`-guarded to compile to an empty module on the host. Verified to fix the host
  build/test (round-2 #A)
- `TASK-001`, `TASK-003`, `RESEARCH.md` — add `from:` version constraints (`swift-dependencies` 1.4.0,
  `swift-tagged` 0.10.0, `swift-snapshot-testing` 1.17.0); a bare `.package(url:)` is invalid SPM.
  Noted TCA's swift-dependencies pin is a lower bound, so unification is conflict-free (round-2 #B)
- `TASK-003` — `AppFeatureSnapshotTests` must be reachable from a shared scheme so `xcodebuild test`
  finds it (+ test-host caveat) (round-2 #C)

### Round 3
- `DECISIONS.md` — cosmetic: remove the "already in the graph transitively" parenthetical that faintly
  echoed the pre-fix framing (round-3 #7; trivial wording tweak)

## Deferred

- (round-1 #5) `CoachTestSupport` linking XCTest as a library is non-idiomatic, but works and the risk
  is already mitigated by manual "test targets only" review checks; structural enforcement (a lint
  guard) is a nice-to-have out of scope for this phase.

## Rejected

- (round-1 #9) Two tasks editing `Package.swift`/`Package.resolved` is coherent — the dependency chain
  serializes the edits and target ownership is non-overlapping (confirmation).
- (round-2 #D) Folded into round-2 #A (the `#if canImport(UIKit)` guard fixes the `swift build` break).
- (round-3 #1–#6, #8) All round-1/round-2 fixes verified present, correct, internally consistent, and —
  for the load-bearing #A guard — empirically validated (an empty-on-host guarded XCTest target compiles
  and `swift test` passes). No new defects. **Final verdict: READY TO IMPLEMENT.**
