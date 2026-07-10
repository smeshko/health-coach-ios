# TASK-003: Multi-modality workout distance extraction

Depends on: None
Suggested commit: `fix(healthkit): read workout distance across cycling/swimming/rowing, not only distanceWalkingRunning`

## Goal

A cycling/swimming/rowing workout uploads a non-nil `distanceM` — distance is read from
the first distance quantity type the workout actually carries statistics for, instead of
only `distanceWalkingRunning`.

## Files

- `Sources/Clients/HealthKitClient/Live/HKSampleMapping.swift` — add
  `static let distanceTypeCandidates: [HKQuantityTypeIdentifier]` (ordered:
  `.distanceWalkingRunning`, `.distanceCycling`, `.distanceSwimming`, `.distanceRowing`,
  `.distanceCrossCountrySkiing`, `.distanceDownhillSnowSports`, `.distancePaddleSports`,
  `.distanceWheelchair`) plus a **pure resolution seam** (validation round-1 #3):
  `static func distanceMeters(sumForType: (HKQuantityTypeIdentifier) -> Double?) -> Double?`
  — walks the candidates, returns the first non-nil. `workoutPayload` calls it with a
  closure that reads `workout.statistics(for: HKQuantityType($0))?.sumQuantity()?
  .doubleValue(for: .meter())` — the only untested line is the statistics read itself.
- `Sources/Clients/HealthKitClient/Tests/HKDistanceCandidatesTests.swift` (new) — tests
  the full resolution result through the pure seam: a cycling-only sums fixture → the
  cycling value; swimming-only → swimming; rowing-only → rowing; walking+running present →
  walkingRunning wins (order); all-nil (strength/rest) → nil. Plus the candidate-list pin
  (contains the four product modalities, walkingRunning first).

## Acceptance

- [ ] `workoutPayload` no longer hardcodes `.distanceWalkingRunning` as the only source —
  it resolves via `distanceMeters(sumForType:)`.
- [ ] Pure-seam tests prove non-nil distance for cycling, swimming, and rowing fixtures,
  order preference for walkingRunning, and nil for a no-statistics workout.
- [ ] Candidate list pinned by test: contains `.distanceWalkingRunning`,
  `.distanceCycling`, `.distanceSwimming`, `.distanceRowing`.

Evidence: HealthKitClient test-suite output with the resolution-seam tests green.

## Notes

- A workout carries statistics only for its own modality's distance type, so
  first-non-nil is exact, not heuristic — no activity-type→distance-type table needed.
- Constructed `HKWorkout`s on the sim don't reliably expose `statistics(for:)`; the pure
  seam takes a `sumForType` closure precisely so tests inject fixtures and only the
  one-line statistics read stays unexercised (repo's pure-seam philosophy).

## Steps

### RED
- [ ] Add `HKDistanceCandidatesTests` pinning the ordered candidate list — fails (list
  absent).

### GREEN
- [ ] Add the candidate list + first-non-nil helper; use it in `workoutPayload`.

### REFACTOR
- [ ] Keep the energy read (`activeEnergyBurned`) untouched; comment the WHY (per-modality
  distance types) in one line.
