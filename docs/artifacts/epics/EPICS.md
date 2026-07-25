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
| 1 | [Foundation & tooling](./01-foundation.md) | 2 | — | Done |
| 2 | [Models & wire contract](./02-models.md) | 3 | Epic 01 | Ready for dev |
| 3 | [Data sources](./03-data-sources.md) | 3 | Epic 01, Epic 02 | Planned |
| 4 | [Repositories](./04-repositories.md) | 5 | Epic 02, Epic 03 | Done |
| 5 | [Design system](./05-design-system.md) | 5 | Epic 01, Epic 02 | Done |
| 6 | [Module file-tree restructure](./06-module-restructure.md) | 4 | Epic 04, Epic 05 | Done |
| 7 | [App shell & onboarding](./07-app-shell-onboarding.md) | 4 | Epic 03, Epic 04, Epic 05, Epic 06 | Done |
| 8 | [Today — daily brief](./08-today-daily-brief.md) | 5 | Epic 04, Epic 05, Epic 06, Epic 07 | Done |
| 9 | [Weekly plan](./09-weekly-plan.md) | 3 | Epic 04, Epic 05, Epic 06, Epic 07, Epic 08, Epic 11 | Done |
| 10 | [Settings & notifications](./10-settings-notifications.md) | 4 | Epic 03, Epic 04, Epic 06, Epic 07, Epic 11 | Done |
| 11 | [Codebase simplification & dead-code removal](./11-simplification.md) | 7 | Epic 02, Epic 03, Epic 04, Epic 05, Epic 07, Epic 08 | Done |
| 12 | [UX feel & motion polish](./12-ux-feel-motion-polish.md) | 4 | Epic 07, Epic 08 | Done |
| 13 | [On-device deterministic engine](./13-ondevice-engine.md) | 5 | Epic 02, Epic 03 | Ready for dev |
| 14 | [Generic onboarding & profile](./14-onboarding-profile.md) | 3 | Epic 13 | Planned |
| 15 | [Local-first product (backend removal)](./15-local-first-product.md) | 3 | Epic 13, Epic 14 | Planned |
| 16 | [Pluggable LLM layer (local + BYO keys)](./16-pluggable-llm.md) | 5 | Epic 13, Epic 15 | Planned |
| 17 | [App Store hardening](./17-appstore-hardening.md) | 3 | Epic 15 | Planned |
| 18 | [Make it run on device (audit wave 1)](./18-run-on-device.md) | 4 | none | Implemented — owner device validation pending |
| 19 | [Make the numbers trustworthy (audit wave 2)](./19-trustworthy-numbers.md) | 7 | Epic 18 | Implemented — owner device validation pending |
| 20 | [Make it adjustable (audit wave 3)](./20-adjustable-architecture.md) | 4 | Epic 19 | Implemented — owner device validation pending |
| 21 | [Home-screen widgets](./21-widgets.md) | 5 | Epic 08, Epic 09 | Implemented — owner device validation pending |

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
