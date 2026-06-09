#if canImport(HealthKit)
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
  }
#endif
