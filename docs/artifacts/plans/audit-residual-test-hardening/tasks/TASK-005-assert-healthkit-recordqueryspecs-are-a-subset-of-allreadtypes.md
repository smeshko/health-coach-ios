# TASK-005: Assert HealthKit recordQuerySpecs are a subset of allReadTypes

Depends on: None
Suggested commit: `test(healthkit): pin recordQuerySpecs ⊆ allReadTypes invariant`

## Goal

Add the cross-catalog invariant: every sample type the live delta read queries
(`HKSampleMapping.recordQuerySpecs`) must be in the authorization read set
(`HKTypeCatalog.allReadTypes`) — a queried type missing from the read set silently
returns nothing on device.

## Files

- `Sources/Clients/HealthKitClient/Tests/HKReadSetCoverageTests.swift` — add the test
  here (it already pins `recordQuerySpecs` against the wire `RecordType` enum, so the
  catalogs are in scope and the run-gate is shared): assert
  `HKSampleMapping.recordQuerySpecs.allSatisfy { HKTypeCatalog.allReadTypes.contains($0.sampleType) }`,
  reporting any spec whose `sampleType` is absent.

## Acceptance

- [ ] A test asserts every `recordQuerySpecs[*].sampleType` is contained in
      `HKTypeCatalog.allReadTypes`; it fails (with the offending type named) if a queried
      type is dropped from the read set.
- [ ] The test runs in the same environment as the existing `HKReadSetCoverageTests`
      (no new host/sim gate divergence).
- [ ] Host + sim suites green.

## Steps

### RED
- [ ] Write the subset assertion (passes today — characterization; the value is catching
      a future spec/read-set drift). If `allReadTypes` is keyed by `HKObjectType` and
      specs carry `HKSampleType`, compare via the sample types' `HKObjectType` identity
      (`Set<HKObjectType>` already contains sample types).

### GREEN
- [ ] n/a — invariant over existing production tables.

### REFACTOR
- [ ] Run the HealthKit suite; host + sim suites.

## Notes

`HKTypeCatalog.allReadTypes` (`HKTypeCatalog.swift:45-46`) is `Set<HKObjectType>`;
`recordQuerySpecs[*].sampleType` (`HKSampleMapping.swift:10`) is `HKSampleType` (an
`HKObjectType` subclass), so `Set.contains` works directly. HK types are constructible in
tests without entitlement (the existing coverage test already does so). Workout/activity
reads are separate paths (`HKObjectType.workoutType()`, activity summaries) — scope this
to the record-query specs the audit flagged; optionally note the workout/activity types
are covered by `allReadTypes` too if cheap.
