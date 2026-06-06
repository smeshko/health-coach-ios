# Adversarial Validation — Round 1

**Run:** 2026-06-06
**Plan:** phase-1-1-spm-app-skeleton
**Status at start:** ready
**Review engine:** Independent adversarial **subagent** (Codex `--scope working-tree` path was
inapplicable — the project is not yet a git repo; Phase 1.1's own TASK-001 is what runs `git init`, so
there is no working tree for Codex to diff, and fabricating one would pre-empt the plan under review).
Substituting an independent adversarial subagent is the documented fallback for this workflow
(`codex-review-rate-limited-subagent-fallback`). The subagent grounded its critique by building the
plan's exact code against the real toolchain (Xcode 26.4 / Swift 6.3; TCA resolved 1.25.5).

## Codex output

<!-- Independent adversarial subagent output, verbatim. -->

## Findings

**#1 — Auto-generated app scheme will likely be gitignored, breaking the committed build & TASK-003's own acceptance command**
- Severity: **high**
- Evidence: TASK-001 (steps) ignores `**/*.xcodeproj/xcuserdata/`, `**/xcuserdata/`, and `*.xcuserstate`. TASK-003 acceptance requires `xcodebuild -resolvePackageDependencies -project CoachApp.xcodeproj -scheme CoachApp` to succeed, and TASK-004 requires `git status` clean. When you create a target from Xcode's App template, the generated `CoachApp` scheme is by default written to `CoachApp.xcodeproj/xcuserdata/.../xcschemes/` and is **not** marked "Shared". With xcuserdata gitignored, the committed repo contains no scheme, so `xcodebuild -scheme CoachApp` and the `ios-build` skill fail on a fresh checkout. Neither DECISIONS.md nor any task mentions marking the scheme **Shared**.
- Suggested verdict: **apply**
- Rationale: A non-shared, gitignored scheme silently defeats the build/launch acceptance criterion on any clean clone or CI.
- If apply: Add a step to TASK-003 GREEN to tick **Shared** so `CoachApp.xcscheme` lands in `CoachApp.xcodeproj/xcshareddata/xcschemes/` and is committed; add an acceptance box that it is tracked by git.

**#2 — `.swiftpm/` and `Package.resolved` location: the app's resolved package state can be ignored, undermining reproducibility**
- Severity: **med**
- Evidence: PLAN.md Scope and TASK-001 ignore `.swiftpm/`. The plan intends `Package.resolved` to be tracked. But there are **two** `Package.resolved` files: the SPM package's (`/Package.resolved`, root — fine) and the **xcodeproj's** at `CoachApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, which is the one the app actually builds against. The broad `.swiftpm/` ignore can mask it.
- Suggested verdict: **apply**
- Rationale: For a local-package reference, the xcodeproj resolves through its own workspace; that `Package.resolved` must be tracked too.
- If apply: State that `CoachApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` is committed, and anchor the `.swiftpm/` glob to the top-level only.

**#3 — Central strict-concurrency claim is CORRECT (verified) — minor doc tightening**
- Severity: low (confirmation)
- Evidence: Verified on the machine — `// swift-tools-version: 6.3` with no `swiftSettings` passes `-swift-version 6`. The claim is accurate. Nuance: `swift build` compiles for the **macOS host**, not iOS, so the "no warnings" guarantee is validated on macOS, not the iOS target.
- Suggested verdict: **apply** (tiny)
- If apply: Note in TASK-002 that `swift build` validates on the host toolchain; iOS-target validation happens via the xcodeproj build in TASK-003.

**#4 — Placeholder TCA code compiles clean with zero warnings (verified) — no defect**
- Severity: low (confirmation)
- Evidence: Built the exact `Package.swift` + `AppFeature.swift` + `AppView.swift` against TCA (`from: "1.17.0"` → 1.25.5) under `-swift-version 6`: Build complete, no warnings.
- Suggested verdict: none

**#5 — `from: "1.17.0"` floor fine; resolves to 1.25.x — no defect**
- Severity: low (confirmation)
- Suggested verdict: none

**#6 — Bundle identifier must survive the template strip-down**
- Severity: med
- Evidence: TASK-003 sets `GENERATE_INFOPLIST_FILE = YES` but the build still needs `PRODUCT_BUNDLE_IDENTIFIER`. "Strip down the template" is hand-wavy about which settings must survive; bundle-id is load-bearing for install/launch.
- Suggested verdict: **apply**
- If apply: TASK-003 GREEN: keep `PRODUCT_BUNDLE_IDENTIFIER` + `PRODUCT_NAME`; only remove `ContentView.swift` and unused settings. (No App Icon / min-macOS / explicit Swift version needed to launch.)

**#7 — Epic says `Package.swift` has "strict-concurrency build settings"; the plan adds none — reconcile**
- Severity: med
- Evidence: Epic 01 line 40 says "strict-concurrency build settings". The plan adds no `swiftSettings` (correct, since the tools-version default already gives complete checking), but TASK-004 ticks that epic box — an adversarial reader can call it a spec deviation.
- Suggested verdict: **apply**
- If apply: add `swiftSettings: [.swiftLanguageMode(.v6)]` to the target (self-documenting, "equivalent and harmless") and/or justify in DECISIONS.md.

**#8 — "No warnings" enforced only on host `swift build`, not the iOS app build**
- Severity: low
- Evidence: PLAN AC "no warnings" is on `swift build`; TASK-003 doesn't assert no-warnings for the xcodeproj/iOS build.
- Suggested verdict: **apply**
- If apply: add "no warnings" to TASK-003 acceptance and TASK-004's build/launch line.

**#9 — Dependency/order coherence sound (git-init precedes commits) — no defect**
- Severity: low (confirmation)
- Suggested verdict: none

**#10 — Scope boundary vs Phase 1.2 is clean — no leakage — no defect**
- Severity: low (confirmation)
- Suggested verdict: none

**#11 — Same-directory local package reference: valid, but ensure it is relative not absolute**
- Severity: low
- Evidence: Same-dir local package works; only the absolute-vs-relative path of the reference is a portability footgun.
- Suggested verdict: **apply** (minor)
- If apply: TASK-003 Note: verify the `XCLocalSwiftPackageReference` `relativePath` is `.`/empty, not absolute.

**Net assessment:** The plan is technically sound and largely implementable as written — the two riskiest concrete claims were verified on the actual toolchain (Xcode 26.4 / Swift 6.3): `swift-tools-version: 6.3` defaults to Swift 6 language mode / complete strict concurrency with no extra flags, and the exact placeholder TCA code builds with zero warnings against real TCA (1.25.5), with `.iOS(.v26)` and the iOS 26 sim present. The most important fixes are the two build-from-checkout hazards in the `.gitignore`/xcodeproj interaction: mark the `CoachApp` scheme **Shared** (#1) and track the xcodeproj's own `Package.resolved` (#2); then tighten "zero warnings" to cover the iOS build (#8) and reconcile the epic's "strict-concurrency build settings" wording (#7).

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | App scheme generated non-shared → gitignored → build/launch unverifiable from a clean clone | high | apply | Verified hazard; defeats the headline acceptance criterion | TASK-003, TASK-001:Notes |
| 2 | xcodeproj's own `Package.resolved` (under `xcshareddata/swiftpm/`) can be ignored | med | apply | That file is what the app builds against; must be tracked | TASK-001, TASK-003 |
| 3 | `swift build` validates host (macOS), not the iOS target | low | apply | Prevents a false sense that no-warnings covers iOS | TASK-002, RESEARCH.md |
| 4 | Placeholder TCA code compiles clean (verified) | low | reject | Confirmation, no change needed | — |
| 5 | TCA `from: "1.17.0"` floor fine (resolves 1.25.x) | low | reject | Confirmation, correct as written | — |
| 6 | Bundle identifier must survive the strip-down | med | apply | Load-bearing for install/launch; strip-down was hand-wavy | TASK-003 |
| 7 | Epic's "strict-concurrency build settings" vs plan adding none | med | apply | Make intent literal so ticking the epic box is defensible | TASK-002, DECISIONS.md |
| 8 | "No warnings" only on host build, not iOS app build | low | apply | Headline promise should cover the shipped build | TASK-003, TASK-004 |
| 9 | Task order/deps coherent (verified) | low | reject | Confirmation, no change | — |
| 10 | Scope partition vs 1.2 clean (verified) | low | reject | Confirmation, no change | — |
| 11 | Local package ref should be relative, not absolute | low | apply | Portability footgun; cheap guard | TASK-003 |
