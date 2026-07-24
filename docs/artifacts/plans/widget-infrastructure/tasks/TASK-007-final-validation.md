# TASK-007: Final Validation

Depends on: all prior tasks
Suggested commit: `chore: final validation for widget-infrastructure`

## Goal

Confirm the plan is fully implemented and production-ready.

## Steps

- [ ] All task checkboxes in `PLAN.md` are ticked
- [ ] `make lint` passes (swiftlint --strict, no issues)
- [ ] `swift build` + full `swift test` pass on the host; the snapshot suite (incl. the new
      `WidgetsUISnapshotTests`) is green on the pinned sim — `make test-snapshots` is SIM-SERIALIZED:
      coordinate the slot, or list it explicitly as pending with the recorded-PNG state
- [ ] Module/import boundaries respected: extension links ONLY WidgetsUI + WidgetSnapshotClientLive +
      DomainModels (pbxproj `packageProductDependencies`); no Database/GRDB/APIClient edge anywhere in
      the new modules; `*Live` imports only at composition roots
- [ ] Manual smoke test via `verify-on-sim` (the epic's Validation): app + widget installed on the
      canonical sim, skeleton widget added to the home screen, in-app Today refresh → snapshot log line +
      widget shows the new date + readiness score (screenshot + log excerpt = the epic's evidence)
- [ ] Deep links smoke-checked on the sim (`xcrun simctl openurl booted coachapp://weekly` etc.)
- [ ] `PLAN.md` acceptance criteria all met, each with its Evidence produced (test output, screenshot,
      log) — no criterion ticked on "the code looks right"
- [ ] Unverified-by-design items restated in the PR body: App Group provisioning on the physical device
      (automatic signing must register `group.com.smeshko.CoachApp` for team GR9SJM3FZP) — owner-side

### Epic update

- [ ] Tick phase 21.1's `### Acceptance criteria` in `docs/artifacts/epics/21-widgets.md`, plus any
      epic-level criteria this phase satisfies
- [ ] Mark the phase done: `python3 ~/.claude/skills/create-epic/scripts/link_plan.py 21 --phase 21.1 --plan widget-infrastructure --status done`
- [ ] Update Epic 21's row in `docs/artifacts/epics/EPICS.md` to `In progress` (21.1 is the first of five
      phases; 21.2–21.5 are now unblocked for parallel implementation)
