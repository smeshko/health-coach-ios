# TASK-004: Final Validation

Depends on: all prior tasks
Suggested commit: `chore: final validation for phase-18-2-bounded-hk-reads`

## Goal

Confirm the plan is fully implemented and production-ready.

## Steps

- [ ] All task checkboxes in `PLAN.md` are ticked
- [ ] Project analyzer/linter passes with no issues
- [ ] Full test suite passes (or every failing-to-run criterion is explicitly listed as CI-pending — see implement-plan's "When CI is the test gate")
- [ ] The iOS-simulator CoachApp build passes and its transcript (showing
  `HKDeltaReads.swift` compiled) is recorded — `make test` is host-only and never compiles
  the `canImport(HealthKit)` arm, and the CoachKit-Package scheme does not list
  `HealthKitClientTests`, so the app-scheme sim build is the automated gate that compiles
  the changed live reader (validation round-1 #3, corrected round-2 #2)
- [ ] Module/import boundaries respected
- [ ] Manual smoke test performed — simulator run: trigger a sync from the Today screen and
  cancel it mid-flight (or background the app); capture the `.app` log line
  ("stopped N in-flight queries") via the dev-menu log viewer or `xcrun simctl` log stream —
  this is the epic's "shown stopping via log/instrumentation" evidence
- [ ] Every `PLAN.md` acceptance criterion EXCEPT the one labelled "CI-pending (owner)" is
  met with its Evidence produced (test output, log excerpt) — the owner's
  large-history-device first sync stays unticked and is recorded in the PR body as pending

### Epic update (only if `PLAN.md`'s `Epic:`/`Phase:` are not `none`)

- [ ] Tick this phase's `### Acceptance criteria` in `docs/artifacts/epics/<NN>-*.md`, plus any epic-level criteria this phase satisfies
- [ ] Mark the phase done: `python3 ~/.claude/skills/create-epic/scripts/link_plan.py <NN> --phase <NN.M> --plan <plan-slug> --status done`
- [ ] Update the epic's row in `docs/artifacts/epics/EPICS.md` (`In progress` after the first phase merges; `Done` when this is the last phase — then tick the remaining epic-level criteria and note any newly-unblocked epics)
