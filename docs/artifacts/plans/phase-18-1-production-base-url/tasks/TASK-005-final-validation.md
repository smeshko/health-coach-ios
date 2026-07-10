# TASK-005: Final Validation

Depends on: all prior tasks
Suggested commit: `chore: final validation for phase-18-1-production-base-url`

## Goal

Confirm the plan is fully implemented and production-ready.

## Steps

- [ ] All task checkboxes in `PLAN.md` are ticked
- [ ] Project analyzer/linter passes with no issues
- [ ] Full test suite passes (or every failing-to-run criterion is explicitly listed as CI-pending — see implement-plan's "When CI is the test gate")
- [ ] Module/import boundaries respected
- [ ] Manual smoke test performed — specifically the TASK-004 simulator runtime run: override
  build with `API_BASE_URL=https://coach.example.com`, `.http` log excerpt shows the client
  targeting the configured host (validation round-1 #3)
- [ ] Every `PLAN.md` acceptance criterion EXCEPT the one explicitly labelled "CI-pending
  (owner)" is met with its Evidence produced (test output, screenshot, log) — no criterion
  ticked on "the code looks right". The CI-pending criterion is NOT a completion blocker for
  this task (implement-plan's "When CI is the test gate" escape hatch); it stays unticked.
- [ ] The CI-pending owner criterion (physical-device probe/sync) is recorded in the PR body
  as a known-pending item, and in the epic file ONLY the acceptance boxes this phase actually
  demonstrated get ticked — the on-device box stays unticked with a `(pending owner device
  run)` note. Marking the phase `--status done` records implementation-complete, not
  device-demonstrated; the epic-level "installs, connects, and syncs on a physical device"
  criterion remains open until the owner's run.

### Epic update (only if `PLAN.md`'s `Epic:`/`Phase:` are not `none`)

- [ ] Tick this phase's `### Acceptance criteria` in `docs/artifacts/epics/<NN>-*.md`, plus any epic-level criteria this phase satisfies
- [ ] Mark the phase done: `python3 ~/.claude/skills/create-epic/scripts/link_plan.py <NN> --phase <NN.M> --plan <plan-slug> --status done`
- [ ] Update the epic's row in `docs/artifacts/epics/EPICS.md` (`In progress` after the first phase merges; `Done` when this is the last phase — then tick the remaining epic-level criteria and note any newly-unblocked epics)
