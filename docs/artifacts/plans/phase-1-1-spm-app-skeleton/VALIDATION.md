# Validation Summary — phase-1-1-spm-app-skeleton

**Rounds:** 3
**Plan status at validation:** ready
**Run on:** 2026-06-06
**Engine:** Independent adversarial subagent (Codex `--scope working-tree` path inapplicable — the
project is not yet a git repo; Phase 1.1's own TASK-001 is what runs `git init`, so there was no working
tree for Codex to diff). Substituting an independent adversarial subagent is the documented fallback for
this workflow (`codex-review-rate-limited-subagent-fallback`). The reviewer grounded findings by building
the plan's exact code against the real toolchain (Xcode 26.4 / Swift 6.3; TCA resolved 1.25.5).

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 11       | 7       | 0        | 4        |
| 2     | 3 (new)  | 1       | 1        | 1        |
| 3     | 0 (new)  | 0       | 0        | 6 (confirmations) |

## Applied

### Round 1
- `TASK-003`, `TASK-001:Notes` — mark the `CoachApp` scheme **Shared** so it is committed and
  `xcodebuild -scheme CoachApp` works from a clean clone (round-1 #1, high)
- `TASK-001`, `TASK-003` — track the xcodeproj's own
  `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`; anchor `/.swiftpm/`; never ignore
  `xcshareddata` (round-1 #2)
- `TASK-002`, `RESEARCH.md` — note `swift build` validates the macOS host, not iOS (round-1 #3)
- `TASK-003` — keep `PRODUCT_BUNDLE_IDENTIFIER`/`PRODUCT_NAME` through the template strip-down
  (round-1 #6)
- `TASK-002` (manifest), `PLAN.md:Decisions` — add explicit `swiftSettings: [.swiftLanguageMode(.v6)]`
  to reconcile the epic's "strict-concurrency build settings" wording (round-1 #7)
- `TASK-003`, `TASK-004` — extend the "no warnings" guarantee to the iOS app build (round-1 #8)
- `TASK-003:Notes` — verify the local-package reference is relative, not absolute (round-1 #11)

### Round 2
- `TASK-002` (manifest), `RESEARCH.md`, `PLAN.md:Decisions` — **[high]** add `.macOS(.v14)` to
  `platforms` so `swift build`/`swift test` compile on the host (TCA requires macOS 13+; an iOS-only
  `platforms` line makes the headline `swift build` criterion unmeetable). Verified to fix it
  (round-2 #12)

## Deferred

- (round-2 #13) `App/Assets.xcassets` vs the "thin target" wording — cosmetic; the acceptance language
  already scopes the "only the app entry point" check to *source files*, and the asset catalog is
  template-standard. No change.

## Rejected

- (round-1 #4, #5, #9, #10) Confirmations, not defects — the placeholder TCA code compiles clean, the
  TCA `from:` floor is fine, task order/deps are coherent, and the 1.1↔1.2 scope partition is clean
  (all verified).
- (round-3 #1–#6) All round-1/round-2 fixes verified present, correct, and consistent; no new defects.
  **Final verdict: READY TO IMPLEMENT.**
