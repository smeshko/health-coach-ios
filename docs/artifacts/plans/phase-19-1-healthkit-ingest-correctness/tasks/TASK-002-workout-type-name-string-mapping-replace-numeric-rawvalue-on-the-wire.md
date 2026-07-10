# TASK-002: Workout type name-string mapping (replace numeric rawValue on the wire)

Depends on: None
Suggested commit: `fix(healthkit): send workout type as the backend's snake_case name string, not the numeric rawValue`

## Goal

`WorkoutPayload.type` carries the snake_case activity-type name the backend contract and
fixtures expect (e.g. `"running"`, `"high_intensity_interval_training"`) instead of the
numeric `HKWorkoutActivityType.rawValue` string that defeats all backend classification.

## Files

- `Sources/Clients/HealthKitClient/Live/HKSampleMapping.swift` — add a pure
  `static func activityTypeName(_ type: HKWorkoutActivityType) -> String` (exhaustive
  `switch` over the SDK's cases → snake_case names matching the backend's canonical form;
  `@unknown default` → `String(type.rawValue)`), and use it in `workoutPayload`.
- `Sources/Clients/HealthKitClient/Tests/HKActivityTypeNameTests.swift` (new) — pins the
  product-relevant modalities (running, walking, hiking, cycling, swimming, rowing,
  traditionalStrengthTraining, functionalStrengthTraining, highIntensityIntervalTraining,
  coreTraining, flexibility/yoga, elliptical, stairClimbing, crossTraining, boxing,
  kickboxing, martialArts, other) to their exact wire strings, plus a
  "no numeric strings for known cases" sweep if a CaseIterable-style list is practical.

## Acceptance

- [ ] `activityTypeName(.running) == "running"`,
  `activityTypeName(.highIntensityIntervalTraining) == "high_intensity_interval_training"`,
  `activityTypeName(.traditionalStrengthTraining) == "traditional_strength_training"` —
  and the rest of the pinned set.
- [ ] `workoutPayload(from:)` uses the mapping (no remaining `String(...rawValue)` on the
  type field).
- [ ] Multi-word names are snake_case (backend `_canonical_activity_type` lowercases
  without splitting camel boundaries — bare camelCase would corrupt).

Evidence: HealthKitClient test-suite output with the new mapping tests green.

## Steps

### RED
- [ ] Add `HKActivityTypeNameTests` asserting the pinned name strings — fails (function
  absent).

### GREEN
- [ ] Implement the exhaustive switch (mechanical: every SDK case → snake_case of the
  case name) and wire it into `workoutPayload`.

### REFACTOR
- [ ] Confirm `HealthKitToWireTests`/`HealthSampleSetFilterTests` fixtures (already name
  strings) still pass — the live shape now matches the tested shape.

## Notes

- HealthKit is importable (and these tests runnable) on the iOS sim; the mapping takes an
  enum, not an `HKWorkout`, so no store is needed.
- Cover ALL `HKWorkoutActivityType` cases in the switch (compiler-enforced
  exhaustiveness); only the pinned subset needs individual test asserts.
- Deprecated SDK cases (e.g. `.dance*` legacy) still need arms — map them to their
  snake_case names too.
