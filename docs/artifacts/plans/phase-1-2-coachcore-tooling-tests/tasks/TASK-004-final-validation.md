# TASK-004: Final Validation

Depends on: all prior tasks
Suggested commit: `chore: final validation for phase-1-2-coachcore-tooling-tests`

## Goal

Confirm the plan is fully implemented and production-ready.

## Steps

- [ ] All task checkboxes in `PLAN.md` are ticked
- [ ] `swift build` passes with **no warnings**; **host logic tests** (`CoachCoreTests` +
      `AppFeatureTests`) pass via `swift test`; **iOS snapshot tests** (`AppFeatureSnapshotTests`) pass
      via `xcodebuild test` on an iOS 26 simulator (the `ios-build` skill)
- [ ] `make lint` and `make format` run **clean** on `Sources/` + `Tests/`
- [ ] Import boundaries respected: `CoachCore` depends only on swift-dependencies + swift-tagged;
      `CoachTestSupport` (XCTest) is depended on **only** by test targets; the app build is clean
- [ ] The `CoachCore` calendar test asserts ISO-week math in Europe/Sofia with `@Dependency` overrides
- [ ] `PLAN.md` acceptance criteria all met

### Epic update (`PLAN.md`'s `Epic:`/`Phase:` are set — Epic 01, Phase 1.2 — the **last** phase)

- [ ] Tick this phase's `### Acceptance criteria` in `docs/artifacts/epics/01-foundation.md` (the three
      Phase 1.2 boxes)
- [ ] Mark the phase done: `python3 .claude/skills/create-epic/scripts/link_plan.py 01 --phase 1.2 --plan phase-1-2-coachcore-tooling-tests --status done`
- [ ] This is Epic 01's **last** phase: tick the **epic-level** acceptance criteria in
      `01-foundation.md` (every phase merged + ACs met; EPICS.md status row updated), set the epic's row
      in `docs/artifacts/epics/EPICS.md` to **`Done`**, and note the now-unblocked epics (Epic 02
      depends only on Epic 01, so it becomes `Ready for dev`; Epic 05 also depends on 01 + 02)
