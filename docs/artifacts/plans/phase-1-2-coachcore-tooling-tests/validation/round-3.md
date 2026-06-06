# Adversarial Validation — Round 3 (final)

**Run:** 2026-06-06
**Plan:** phase-1-2-coachcore-tooling-tests
**Status at start:** ready
**Prior rounds in scope:** validation/round-1.md, validation/round-2.md
**Review engine:** Independent adversarial **subagent** (Codex working-tree path inapplicable — pre-git
project; documented fallback). Verified empirically on Xcode 26.4 / Swift 6.3 + TCA 1.25.5 /
swift-snapshot-testing 1.19.2.

## Codex output

<!-- Independent adversarial subagent output, verbatim. -->

**#1 — Round-2 #A (`#if canImport(UIKit)` guards) landed correctly, consistently, AND empirically valid.**
Required in PLAN.md:Risks, RESEARCH.md §4.6 note, and TASK-003 (Files/Acceptance/Steps/note).
Reproduced both directions on Swift 6.3/Xcode 26.4: unguarded `import UIKit` → `swift build` fails
`no such module 'UIKit'`; fully guarded (entire test body in `#if canImport(UIKit)`, zero test methods
on host) → both `swift build` and `swift test` exit 0 (runner reports the real `AppFeatureTests` test
plus "0 tests" for the empty target). The "does an empty guarded XCTest target break the run?" worry is
answered: **no.** No change.

**#2 — Round-2 #B (`from:` version constraints) landed correctly.** `swift-dependencies from: "1.4.0"`,
`swift-tagged from: "0.10.0"`, `swift-snapshot-testing from: "1.17.0"`; the TCA-pin (lower bound, not
`exact`) → conflict-free unification reasoning is sound. No change.

**#3 — Round-2 #C (shared scheme + test-host caveat) landed correctly.** TASK-003 Acceptance +
RESEARCH note. No change.

**#4 — All round-1 applies remain coherent** (direct swift-dependencies dep; not via
ComposableArchitecture; target split; two run-paths; YAGNI; record API; onAppear hedge). grep-clean of
any "Dependencies comes from TCA" false claim. No change.

**#5 — `CoachCore`'s dependency set correct and complete** (swift-dependencies + swift-tagged only;
`CoachCoreTests` adds `Dependencies` for overrides). Matches §4.1/§18 + bottom-of-graph rule. No change.

**#6 — All three Phase 1.2 epic acceptance criteria satisfied** (CoachCore+calendar dep; lint clean;
sample snapshot + TestStore; + the ISO-week validation); "shared extensions" explicitly satisfied-by-
YAGNI. TASK-004 ticks the epic boxes + marks Epic 01 done. No change.

**#7 — Minor cosmetic residue in DECISIONS.md** ("already in the graph transitively" parenthetical could
faintly echo round-1's pre-fix framing). Severity low. Verdict: defer (cannot mislead — direct-dep
requirement is unambiguous one line up). *[Applied anyway post-round-3 as a trivial wording tweak.]*

**#8 — No new contradictions introduced.** Guarded-to-empty module compiles with zero warnings (no
conflict with the no-warnings AC); dependency graph acyclic; ownership non-overlapping; relies
correctly on Phase 1.1's `[.iOS(.v26), .macOS(.v14)]` manifest.

### Genuine remaining apply-level defects: none.

**Net assessment: READY TO IMPLEMENT**

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Round-2 #A guards landed + empirically valid (empty host target OK) | n/a | reject | Confirmation, verified | — |
| 2 | Round-2 #B `from:` constraints landed + unification conflict-free | n/a | reject | Confirmation, verified | — |
| 3 | Round-2 #C shared scheme/test-host landed | n/a | reject | Confirmation | — |
| 4 | Round-1 applies still coherent | n/a | reject | Confirmation | — |
| 5 | `CoachCore` dep set correct | n/a | reject | Confirmation | — |
| 6 | All Phase 1.2 epic ACs satisfied | n/a | reject | Confirmation | — |
| 7 | Cosmetic "transitively" residue in DECISIONS.md | low | defer→applied | Trivial wording tweak applied post-round-3 | DECISIONS.md |
| 8 | No new contradictions introduced | n/a | reject | Confirmation | — |

**Outcome: clean (no material apply rows). Plan ready for implement-plan.**
