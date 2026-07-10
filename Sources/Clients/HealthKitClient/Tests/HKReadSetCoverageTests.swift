#if canImport(HealthKit)
  import HealthKit
  import Testing
  import WireModels

  @testable import HealthKitClientLive

  /// Guards the **live read set** against the wire `RecordType` set — the interface coverage test
  /// (`HealthDataCategoryTests`) is blind to `recordQuerySpecs`, so this is the test that catches a
  /// wire type the live reader forgets to query (round-1 review #1: `physical_effort` was dropped).
  struct HKReadSetCoverageTests {
    @Test func test_recordQuerySpecs_coverEveryRecordType_exceptCadence() {
      let produced = Set(HKSampleMapping.recordQuerySpecs.map(\.recordType))
      // `running_cadence` is the ONLY sanctioned exception (no first-class HKQuantityTypeIdentifier).
      let expected = Set(RecordType.allCases).subtracting([.runningCadence])
      #expect(produced == expected)
    }

    @Test func test_recordQuerySpecs_haveNoDuplicateRecordType() {
      let types = HKSampleMapping.recordQuerySpecs.map(\.recordType)
      #expect(types.count == Set(types).count)
    }

    /// Cross-catalog invariant (audit residual): every sample type the live delta read queries must be in
    /// the authorization read set. A queried type absent from `allReadTypes` is never authorized, so on
    /// device it silently returns nothing — no error, just missing data. `allReadTypes` is a
    /// `Set<HKObjectType>` and each `sampleType` is an `HKSampleType` (an `HKObjectType` subclass), so
    /// `contains` compares them directly.
    @Test func test_recordQuerySpecs_areSubsetOfAllReadTypes() {
      let readSet = HKTypeCatalog.allReadTypes
      let missing = HKSampleMapping.recordQuerySpecs
        .map(\.sampleType)
        .filter { !readSet.contains($0) }
      #expect(
        missing.isEmpty,
        "queried sample types missing from the authorization read set: \(missing.map(\.identifier))"
      )
    }

    /// TASK-004 (validation round-1 #5): the effort quantity types are read via the per-workout
    /// relationship query, NOT via `recordQuerySpecs`, so the subset guard above is structurally
    /// blind to their omission — assert their membership in the read set directly and
    /// unconditionally. (The `@available` gate covers only the macOS 14 host floor; the package's
    /// iOS 26 floor always runs this.)
    @available(macOS 15.0, *)
    @Test func test_effortQuantityTypes_areMembersOfAllReadTypes() {
      let readSet = HKTypeCatalog.allReadTypes
      #expect(
        readSet.contains(HKQuantityType(.workoutEffortScore)),
        "workoutEffortScore is never authorized → relationship reads silently return nothing"
      )
      #expect(
        readSet.contains(HKQuantityType(.estimatedWorkoutEffortScore)),
        "estimatedWorkoutEffortScore is never authorized → relationship reads silently return nothing"
      )
    }
  }
#endif
