# Adversarial Validation — Round 2

**Run:** 2026-06-06
**Plan:** phase-1-1-spm-app-skeleton
**Status at start:** ready
**Prior rounds in scope:** validation/round-1.md
**Review engine:** Independent adversarial **subagent** (Codex working-tree path inapplicable — pre-git
project; documented fallback). Verified empirically on Xcode 26.4 / Swift 6.3.

## Codex output

<!-- Independent adversarial subagent output, verbatim. -->

Round-1 edits all landed correctly per the triage. Second-pass review:

## Round-1 applied findings — verification

**#1 — Shared scheme** — verified sound. Files/GREEN/Acceptance all carry the shared-scheme step; empirically confirmed gitignore keeps `xcshareddata/xcschemes/CoachApp.xcscheme` tracked while ignoring `xcuserdata`. Verdict: reject (no change).

**#2 — xcodeproj `Package.resolved` + anchored `/.swiftpm/` glob** — verified sound. Empirically verified the anchored `/.swiftpm/` ignores top-level scratch while leaving `xcshareddata/swiftpm/Package.resolved` tracked. Verdict: reject (no change).

**#3 — host-vs-iOS build note** — landed, but framing is now actively misleading given #12 (it asserts the host build is the package's no-warnings guarantee, which is impossible without a `.macOS` platform). Verdict: apply (fix via #12).

**#6 — bundle id survives strip-down** — landed verbatim. Verdict: reject (no change).

**#7 — explicit `.swiftLanguageMode(.v6)`** — verified valid API on Swift 6.3 (parses, appears in dump-package, builds clean). No contradiction with the "don't add other flags" note (it forbids only the Swift-5-mode flag/upcoming-feature). Verdict: reject (no change).

**#8 — no-warnings on iOS build** — landed in TASK-003 + TASK-004. Verdict: reject (no change).

**#11 — relative local package ref** — landed verbatim. Verdict: reject (no change).

## Round-1 reject rows pushback
**#9, #10, #5** — agree, clean confirmations. **#4 — DISPUTED:** round-1 #4 claimed the exact `Package.swift` builds clean, but that cannot be true for the literal iOS-only `platforms` line — the verification must have silently used a macOS platform/iOS destination. See #12.

## NEW findings

**#12 — Plan's literal `Package.swift` (iOS-only platforms) FAILS `swift build`; defeats the headline acceptance criterion**
- Severity: **high**
- Evidence (reproduced on Xcode 26.4 / Swift 6.3): building TASK-002's exact manifest with `platforms: [.iOS(.v26)]` + TCA produces `error: the library 'AppFeature' requires macos 10.13, but depends on the product 'ComposableArchitecture' which requires macos 13.0…`. Resolution succeeds; compilation fails. Adding `.macOS(.v15)`/`.v13`+ to `platforms` makes `swift build` complete cleanly with zero warnings (also reproduced). The round-1 edits made the host build the load-bearing no-warnings guarantee while leaving the manifest that makes it impossible.
- Verdict: **apply**
- What to change: Add `.macOS(.v13+)` to `platforms` in TASK-002's manifest; note it exists solely to let the host `swift build`/tests compile and does not weaken the iOS-26 product baseline (app target stays iOS-only).

**#13 — `App/Assets.xcassets` not reconciled with the "thin target" language**
- Severity: low
- Evidence: TASK-003 lists `App/Assets.xcassets/`; the "no source beyond the @main entry point" check (TASK-004) only polices *source*, so an asset catalog isn't a violation, but an adversarial reader might misread it.
- Verdict: **defer** (cosmetic; acceptance language already scopes to "source files," and the catalog is template-standard).

**#14 — TASK-004 still covers every PLAN.md acceptance criterion** — verified; coverage intact post-edit. Verdict: reject (no change). (Caveat: AC "swift build succeeds" is undermined by #12 — a manifest defect, not a coverage gap.)

**Net assessment:** The seven round-1 `apply` edits all landed correctly, are technically sound, and are sufficient (gitignore/xcshareddata semantics and `.swiftLanguageMode(.v6)` empirically verified). However the plan is **not yet ready** due to one pre-existing high-severity defect the edits reinforced: the literal `Package.swift` declares only `.iOS(.v26)`, so `swift build` (host) fails against TCA's macOS-13 floor. Add `.macOS(.v13+)` to `platforms` (verified to fix it).

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Round-1 #1 (shared scheme) landed + correct | low | reject | Verified sufficient | — |
| 2 | Round-1 #2 (xcodeproj resolved + anchored glob) landed + correct | low | reject | Verified sufficient | — |
| 3 | Round-1 #3 host-build note now misleading w/o `.macOS` | med | apply | Reframed by the #12 edit (RESEARCH/TASK-002 updated) | TASK-002, RESEARCH.md |
| 4 | Round-1 #4 "build clean" claim was platform-dependent | high→ | apply | Real root cause is #12; addressed there | (via #12) |
| 6 | Round-1 #6 (bundle id) landed + correct | low | reject | Verified sufficient | — |
| 7 | Round-1 #7 (`.swiftLanguageMode(.v6)`) landed + correct | low | reject | Verified valid API, no contradiction | — |
| 8 | Round-1 #8 (iOS no-warnings) landed + correct | low | reject | Verified sufficient | — |
| 11 | Round-1 #11 (relative pkg ref) landed + correct | low | reject | Verified sufficient | — |
| 12 | **NEW:** iOS-only `platforms` makes host `swift build` fail vs TCA macOS-13 floor | high | apply | Verified; add `.macOS` to platforms | TASK-002, RESEARCH.md, PLAN.md:Decisions |
| 13 | **NEW:** `App/Assets.xcassets` vs "thin target" wording | low | defer | Cosmetic; AC scopes to "source files" | — |
| 14 | TASK-004 coverage intact post-edit | none | reject | Verified complete | — |
