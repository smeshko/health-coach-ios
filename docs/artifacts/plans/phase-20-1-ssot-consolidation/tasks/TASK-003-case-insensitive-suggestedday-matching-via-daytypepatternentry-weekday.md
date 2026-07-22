# TASK-003: Case-insensitive suggestedDay matching via DayTypePatternEntry.weekday

Depends on: None
Suggested commit: `fix(models): case-insensitive suggestedDay so carb-cycling entries can't silently render as rest days`

## Goal

A case-mismatched `suggestedDay` (`"Tue"`, `"TUE"`) places its carb-cycling bar on the
right day instead of silently falling through to the rest-day cut. The interpretation
of the free wire string lives once, on the domain type, and the view compares enum
values (DECISIONS D5).

## Files

- `Sources/Models/DomainModels/Sources/Nutrition.swift` — on `DayTypePatternEntry`
  (:74): `public var weekday: Weekday? { Weekday(rawValue: suggestedDay.lowercased()) }`
  with a doc line stating this is THE reading of the free string (consumers must not
  re-parse `suggestedDay`). The stored string stays verbatim (wire fidelity).
- `Sources/DesignSystem/Sources/Composites/CarbCyclingPattern.swift` :44 —
  `dayTypePattern.first(where: { $0.weekday == weekday })`; drop the `.rawValue`
  string comparison. Doc comment on `resolvedDays` (:40) updated.
- `Sources/Models/DomainModels/Tests/ValueTypeTests.swift` — weekday-normalization
  cases (Swift Testing, matching the file's existing style).

## Acceptance

- [ ] `ValueTypeTests` pins: `"tue"` → `.tue` (unchanged path), `"Tue"` → `.tue`,
  `"TUE"` → `.tue`, `"notaday"` → `nil`, `""` → `nil`.
- [ ] `CarbCyclingPattern` contains no string comparison against `rawValue`; the match
  is `Weekday` equality via `entry.weekday`.
- [ ] Rendered output for well-formed (lowercase) data is unchanged — the gallery
  fixtures (`CarbCyclingPatternPage` :24–27/:40–42) are lowercase, so
  `CarbCyclingPatternSnapshotTests` PNGs stay byte-identical (not run here; noted for
  the report). A mismatched-case entry rendering its bar is the corrective change the
  phase asks for.
- [ ] Full host suite green.

Evidence: `swift test` output for the DomainModels target (new cases visible).

## Steps

### RED
- [ ] Add the `ValueTypeTests` cases — `"Tue"`/`"TUE"` fail to resolve before the
  property exists (compile-red, then assert-red with a naive `Weekday(rawValue:)`
  strawman if staged that way).

### GREEN
- [ ] Add `weekday` to the domain struct; switch the view's predicate.

### REFACTOR
- [ ] Confirm no other consumer parses `suggestedDay` by hand (grep `suggestedDay` —
  today only `CarbCyclingPattern` touches the free-string variant; the typed
  `PlannedSession.suggestedDay: Weekday?` sites are unaffected).

## Notes

- Deliberately NOT mapping the string to `Weekday` at the wire→domain boundary: the
  openapi contract keeps it free, and coercing there would silently rewrite data the
  domain promises to carry verbatim (`suggestedDay` doc, Nutrition.swift:72–73).
  Interpretation-on-read keeps both truths.
- Full-name aliases ("Tuesday") are out of scope — the backend emits `mon…sun` keys;
  only case drift is the observed hazard.
