# TASK-004: Final Validation

Depends on: all prior tasks
Suggested commit: `chore: final validation for phase-1-1-spm-app-skeleton`

## Goal

Confirm the plan is fully implemented and production-ready.

## Steps

- [ ] All task checkboxes in `PLAN.md` are ticked
- [ ] `swift build` passes with **no warnings** under the Swift 6 language mode
- [ ] The `CoachApp` scheme builds and launches on an iOS 26 simulator (via the `ios-build` skill)
      **with no warnings** and the placeholder `AppView` renders
- [ ] Import boundaries respected: the app target imports `AppFeature`; the package has no dependency
      on the app target; no source beyond the `@main` entry point lives in the xcodeproj / `App/`
- [ ] `git status` is clean; `.gitignore` keeps `.build/` / `DerivedData/` / `xcuserdata` untracked
      while the **shared scheme** and both `Package.resolved` files (root + xcodeproj) are tracked
- [ ] `PLAN.md` acceptance criteria all met

### Epic update (`PLAN.md`'s `Epic:`/`Phase:` are set — Epic 01, Phase 1.1)

- [ ] Tick this phase's `### Acceptance criteria` in `docs/artifacts/epics/01-foundation.md` (the four
      Phase 1.1 boxes)
- [ ] Mark the phase done: `python3 .claude/skills/create-epic/scripts/link_plan.py 01 --phase 1.1 --plan phase-1-1-spm-app-skeleton --status done`
- [ ] Update the epic's row in `docs/artifacts/epics/EPICS.md` to **`In progress`** (this is the first
      of Epic 01's two phases; it becomes `Done` only after Phase 1.2 merges — do **not** tick the
      epic-level acceptance criteria yet)
