# Implementation Epics

This document tracks the implementation epics for **Coach App iOS**. Each epic is a
self-contained unit of functionality; each phase within an epic is sized to fit a
small-to-medium pull request and maps to exactly one plan under
[`../plans/`](../plans/).

## Status legend

| Status | Meaning |
|---|---|
| Planned | Defined but not started |
| Ready for dev | All dependencies met; can be picked up |
| In progress | At least one phase has been merged |
| Done | All phases complete and validated against the acceptance criteria |
| Blocked | Waiting on a prerequisite epic |

## Epic status

| # | Epic | Phases | Dependencies | Status |
|---|------|--------|--------------|--------|
| 1 | [Foundation & tooling](./01-foundation.md) | 2 | — | Ready for dev |
| 2 | [Models & wire contract](./02-models.md) | 3 | Epic 01 | Planned |
| 3 | [Data sources](./03-data-sources.md) | 3 | Epic 01, Epic 02 | Planned |
| 4 | [Repositories](./04-repositories.md) | 5 | Epic 02, Epic 03 | Planned |
| 5 | [Design system](./05-design-system.md) | 3 | Epic 01, Epic 02 | Planned |
| 6 | [App shell & onboarding](./06-app-shell-onboarding.md) | 4 | Epic 03, Epic 04, Epic 05 | Planned |
| 7 | [Today — daily brief](./07-today-daily-brief.md) | 4 | Epic 04, Epic 05, Epic 06 | Planned |
| 8 | [Weekly plan](./08-weekly-plan.md) | 3 | Epic 04, Epic 05, Epic 06, Epic 07 | Planned |
| 9 | [Settings & notifications](./09-settings-notifications.md) | 3 | Epic 03, Epic 04, Epic 06 | Planned |

## How to work with these epics

1. Confirm this epic's dependencies are `Done` in the table above.
2. Open the epic file and start with its first phase.
3. Turn a phase into a plan: `create-plan` with `--epic <NN> --phase <NN>.<M>`
   (links the plan to the phase both ways). Then `validate-plan` →
   `implement-plan` → `review-plan` → `create-pr` → `archive-plan`.
4. Each phase lands as its own pull request.
5. The plan's final-validation task ticks the phase + epic-level acceptance
   criteria and updates this table — promote the row to `In progress` after the
   first phase merges, and to `Done` when the last one does.
