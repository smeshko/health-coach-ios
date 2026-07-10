# TASK-002: Day-guard the check-in footer copy

Depends on: None
Suggested commit: `fix(today): day-guard the "Saved earlier today" check-in footer`

## Goal

The "Saved earlier today" footer can never lie about the day: it renders only when
`existing.date` is the current Sofia day, so even a delayed/missed reset or child-reload
window cannot show yesterday's save as today's (defense in depth on top of TASK-001 —
DECISIONS D3).

## Files

- `Sources/Features/TodayFeature/Sources/CheckInComponent.swift` — expose the guard as
  state-derived truth: e.g. `var existingIsToday: Bool` computed against the injected
  `@Dependency(\.calendar)`/`\.date` at reduce time, or (simpler, view-safe) a pure
  `static func isSameSofiaDay(_ existing: CheckIn?, now: Date, calendar: Calendar) ->
  Bool` the view calls — pick whichever matches the component's existing
  dependency-access pattern; the logic is one `calendar.isDate(_:inSameDayAs:)`.
- `Sources/Features/TodayFeature/Sources/CheckInSection.swift` — the footer branch
  `else if store.existing != nil` additionally requires the day-guard; `lastSavedAt`
  needs no guard (session-local, cleared by TASK-001's reset — note WHY in one line).
- `Sources/Features/TodayFeature/Tests/TodayFeatureTests/CheckInComponentTests.swift`
  (or the section's test home) — cases: existing dated today → footer copy renders
  (unchanged); existing dated yesterday → no footer; nil existing → no footer
  (unchanged).

## Acceptance

- [ ] Yesterday-dated `existing` renders no "Saved earlier today" footer.
- [ ] Today-dated `existing` keeps the exact current footer copy (no same-day behavior
  change).
- [ ] Guard logic is pure and unit-tested with the Europe/Sofia calendar (a 23:59 vs
  00:01 boundary pair).

Evidence: TodayFeature test-suite output for the new footer cases.

## Steps

### RED
- [ ] Add the yesterday-existing footer test — fails (footer currently renders on any
  non-nil `existing`).

### GREEN
- [ ] Add the day-guard + wire the footer branch.

### REFACTOR
- [ ] Keep the guard in one place (component), not duplicated in the view; the only
  check-in snapshot (`TodayViewSnapshotTests.test_checkIn`) seeds `lastSavedAt` — never
  `existing` — so PNGs stay byte-identical (validation round-1 #10); prefer the pure
  `isSameSofiaDay(_:now:calendar:)` form over a view-time `\.date` read for exactly
  that determinism.

## Notes

- `CheckIn.date` is already normalized to Sofia `startOfDay` by the repository on save;
  the guard still uses `isDate(_:inSameDayAs:)` (not `==`) so an un-normalized value
  from any future source stays correct.
