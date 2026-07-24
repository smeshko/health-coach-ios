# Validation Summary — widget-infrastructure

**Rounds:** 2
**Plan status at validation:** draft
**Run on:** 2026-07-24

## Rounds

| Round | Findings | Applied | Deferred | Rejected |
|-------|----------|---------|----------|----------|
| 1     | 4        | 4       | 0        | 0        |
| 2     | 0        | 0       | 0        | 0        |

Round-1 reviewer: Codex (`codex-cli 0.144.5`) — read all plan files + referenced source and flagged two
load-bearing issues before the foreground run hit the 10-minute harness cap and was terminated; the
validator re-grounded those two against current source and completed the coherence sweep inline. Round 2
ran as the inline-lens fallback (Codex foreground reproducibly exceeds the cap) to verify the applied
edits and re-sweep for edit-induced problems. No AskUserQuestion was raised: this is a non-interactive
workflow run, and none of the four findings were request-scope judgment calls — all are codebase-
correctness / coherence fixes grounded in files read directly.

## Applied

### Round 1
- **TASK-003** (round-1 #1, high) — `case deepLink(URL)` on `AppFeature.Action` also makes the *second*
  exhaustive switch in `AppFeature+SessionRouting.swift` (`reduceSessionRouting`, no `default`)
  non-exhaustive → compile error. Task now mandates adding `.deepLink` to that catch-all arm, with a GREEN
  step and a TASK-007 compile check.
- **TASK-002** (round-1 #2, med) — the daily merge preserved `selectedSession` unconditionally, carrying a
  prior day's selection into a new-day snapshot (a stale-day bug frozen into the 21.1 merge contract for
  21.2 to inherit). Task now guards preservation by same-Sofia-day (`isCurrent` / Sofia `startOfDay`
  equality) and adds a cross-day-drop acceptance case.
- **PLAN.md:Risks + TASK-002** (round-1 #3, med) — the store's read→merge→atomic-write is not atomic
  across concurrent writers; 21.1 freezes the design for later phases whose sibling section writers all
  mutate the same file → lost updates. Added a Risk and a TASK-002 note steering the live client to
  serialize writes through a single actor while keeping the pure merge a host-testable free function.
- **TASK-007** (round-1 #4, low) — final-validation checklist didn't enumerate PLAN.md acceptance criteria
  5/6/7/8; added explicit evidence lines so every criterion is named, not ticked on "looks right."

### Round 2
- (none — round-1 edits verified sufficient and self-consistent)

## Deferred

- (none)

## Rejected

- (none — the coherence sweep re-confirmed several load-bearing plan claims rather than rejecting Codex
  findings: liveValue dynamic resolution from the extension process is sound (LogClient split verified);
  the extension's transitive dependency closure — WidgetsUI → DesignSystem → {DomainModels, CoachCore,
  HealthKitClient interface → WireModels} — carries no Database/GRDB/APIClient edge (acceptance #4 holds);
  `#if canImport(WidgetKit)` guard-always covers the macOS host; the `.checkIn`→Today route is the
  deliberate DECISIONS D5; and `DEVELOPMENT_TEAM = GR9SJM3FZP` currently appears exactly twice with the
  LogClientLive foursome pattern intact, matching the TASK-005/006 pbxproj spec.)
