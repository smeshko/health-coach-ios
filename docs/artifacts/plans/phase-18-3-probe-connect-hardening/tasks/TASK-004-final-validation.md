# TASK-004: Final Validation

Depends on: all prior tasks
Suggested commit: `chore: final validation for phase-18-3-probe-connect-hardening`

## Goal

Confirm the plan is fully implemented and production-ready.

## Steps

- [ ] All task checkboxes in `PLAN.md` are ticked
- [ ] Project analyzer/linter passes with no issues
- [ ] Full test suite passes (or every failing-to-run criterion is explicitly listed as CI-pending — see implement-plan's "When CI is the test gate")
- [ ] Module/import boundaries respected
- [ ] Manual smoke test performed — simulator run: with mock mode OFF and an unreachable
  server, Connect shows the UNREACHABLE copy (screenshot), not "token invalid"; the priming
  step settles out of `.checking` to the degraded screen when the probe can't complete
- [ ] Every `PLAN.md` acceptance criterion EXCEPT the one labelled "CI-pending (owner)" is
  met with its Evidence produced (test output, screenshot, log) — the owner's on-device
  slow-probe validation stays unticked and is recorded in the PR body
- [ ] The two carried 18.1 defers are explicitly closed in the PR body (config-failure
  presentation; unreachable ≠ token-rejected) — reference the 18.1 REVIEW.md defer text

### Epic update (only if `PLAN.md`'s `Epic:`/`Phase:` are not `none`)

- [ ] BEFORE ticking, amend the epic's 18.3 acceptance wording (validation round-1 #5):
  the epic says "a transient probe failure does not clear an otherwise-valid token", but
  the implemented semantics are cancellation + presentation (the candidate IS cleared on
  every failure for restore-safety; a stale probe can never clobber a newer candidate
  because it is cancelled, and failures render unreachable vs invalid distinctly).
  Rewrite the AC/Validation lines in `docs/artifacts/epics/18-run-on-device.md` to that
  effect with a one-line rationale — do not tick a box the code intentionally does not
  meet as written
- [ ] Tick this phase's `### Acceptance criteria` in `docs/artifacts/epics/<NN>-*.md`, plus any epic-level criteria this phase satisfies
- [ ] Mark the phase done: `python3 ~/.claude/skills/create-epic/scripts/link_plan.py <NN> --phase <NN.M> --plan <plan-slug> --status done`
- [ ] Update the epic's row in `docs/artifacts/epics/EPICS.md` (`In progress` after the first phase merges; `Done` when this is the last phase — then tick the remaining epic-level criteria and note any newly-unblocked epics)
