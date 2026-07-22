# TASK-004: Final Validation

Depends on: TASK-001, TASK-002, TASK-003
Suggested commit: none (validation only; fixes fold into the owning task's follow-up commit)

## Goal

The phase's acceptance criteria are demonstrated, the gates are green from the
worktree root, and the snapshot impact is enumerated for the ship stage — without
touching the shared simulator.

## Checklist

- [ ] `make lint` — swiftlint --strict, 0 violations (the removed
  `cyclomatic_complexity` disables resurface nothing).
- [ ] `make test` — full host package suite green; capture the tail (test counts) for
  the report.
- [ ] SSOT greps, captured as evidence:
  - `grep -rn "EnumMapping" Sources` → no hits.
  - `grep -rn "needs_green_knee" Sources --include="*.swift"` → exactly one non-test
    hit (Flag.swift's `wireString`); spot-check one string per enum likewise.
  - `grep -rn "score >= 75\|score >= 50" Sources` → no hits.
  - `grep -rn "suggestedDay == \|rawValue" Sources/DesignSystem/Sources/Composites/CarbCyclingPattern.swift`
    → no string-comparison match remains.
- [ ] PLAN.md acceptance-criteria checkboxes updated with evidence notes (test names,
  grep results), task checkboxes ticked.
- [ ] Report drafts the snapshot-impact list for the ship stage (DO NOT run
  `make test-snapshots`): expected diffs = readiness-meter axis label "Ease off" →
  "Ease Off" in `BarsSnapshotTests` (readiness section), `ReadinessSnapshotTests`,
  meter-showing `TodayViewSnapshotTests` cases; expected byte-identical =
  `CarbCyclingPatternSnapshotTests` and every other suite.

## Acceptance

- [ ] All PLAN.md acceptance criteria checked with evidence.
- [ ] Gates green; outputs quoted in the final report.
- [ ] Unverified-by-design items explicitly listed in the report: snapshot renders
  (ship stage) and on-device behavior (owner validation).

Evidence: lint + test tails and the grep transcript, quoted in the orchestrator report.
