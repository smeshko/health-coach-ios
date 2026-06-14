# TASK-008: Final Validation

Depends on: all prior tasks
Suggested commit: `chore: final validation for audit-residual-test-hardening`

## Goal

Confirm the plan is fully implemented and production-ready.

## Steps

- [ ] All task checkboxes in `PLAN.md` are ticked
- [ ] `swift build` + `swift test` (host) pass
- [ ] Sim unit tests green: `xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace
      -scheme CoachKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'`
- [ ] `make lint` exits 0
- [ ] The ONLY production change is the LogViewer `.cancellable` fix (TASK-001);
      everything else is test-only (`git diff --stat` confirms)
- [ ] Each new test is deterministic (no wall-clock sleeps; gated continuations /
      `TestClock` only) and passes on repeated runs
- [ ] No temp-file/temp-dir leakage from the `makeLive` / `LogFileWriter` tests
- [ ] Every PLAN.md acceptance criterion met; the audit's residual items (gap #8
      concurrency, Database/HealthKit/LogClient module gaps, the two WEAK verdicts) are
      each closed or — for `perTabStacks` — explicitly noted as blocked

### Epic update

Not applicable — this is a standalone plan (`Epic:`/`Phase:` are `none`). On merge,
update the memory note [[test-audit-epic11-absorption]] to record that the residual tail
shipped, so the audit is fully accounted for.
