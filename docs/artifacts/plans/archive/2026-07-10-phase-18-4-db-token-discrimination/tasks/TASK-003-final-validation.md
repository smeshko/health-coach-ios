# TASK-003: Final Validation

Depends on: all prior tasks
Suggested commit: `chore: final validation for phase-18-4-db-token-discrimination`

## Goal

Confirm the plan is fully implemented and production-ready.

## Steps

- [ ] All task checkboxes in `PLAN.md` are ticked
- [ ] Project analyzer/linter passes with no issues
- [ ] Full test suite passes (or every failing-to-run criterion is explicitly listed as CI-pending — see implement-plan's "When CI is the test gate")
- [ ] Module/import boundaries respected
- [ ] Manual smoke test performed — simulator: normal launch still lands on `.main` with a
  stored token / onboarding without one; app builds + boots (the DB/keychain failure paths
  themselves are TestStore/unit-proven — do not fake filesystem corruption on the sim)
- [ ] Every `PLAN.md` acceptance criterion EXCEPT the one labelled "CI-pending (owner)" is
  met with its Evidence produced — the owner's on-device fault-injection stays unticked and
  is recorded in the PR body
- [ ] THIS IS THE LAST PHASE: after the epic update below, verify with
  `python3 ~/.claude/skills/create-epic/scripts/epic_status.py 18` that all four phases
  read done; tick ONLY the epic-level criteria that are actually demonstrated. Do NOT set
  the EPICS.md row to `Done` (validation round-1 #2 — device-run criteria across 18.1/18.2
  and the epic-level "installs, connects, syncs on a physical device" box remain open):
  set it to `Implemented — owner device validation pending`, and list the open owner
  criteria in the PR body

### Epic update (only if `PLAN.md`'s `Epic:`/`Phase:` are not `none`)

- [ ] Tick this phase's `### Acceptance criteria` in `docs/artifacts/epics/<NN>-*.md`, plus any epic-level criteria this phase satisfies
- [ ] Mark the phase done: `python3 ~/.claude/skills/create-epic/scripts/link_plan.py <NN> --phase <NN.M> --plan <plan-slug> --status done`
- [ ] Update the epic's row in `docs/artifacts/epics/EPICS.md` (`In progress` after the first phase merges; `Done` when this is the last phase — then tick the remaining epic-level criteria and note any newly-unblocked epics)
