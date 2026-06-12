import Testing
import WireModels

@testable import HealthKitClient

struct HealthDataCategoryTests {
  @Test func test_categoryMapping_coversEveryWireRecordType_exactly() {
    let mapped = Set(HealthDataCategory.allCases.flatMap(\.recordTypes))
    // `RecordType` is the wire-local, CaseIterable enum (no tolerant wrapper — it decodes strictly),
    // so its `allCases` is the source of truth.
    #expect(mapped == Set(RecordType.allCases))
    #expect(mapped.count == 24, "the wire RecordType set has 24 values")
  }

  @Test func test_workoutsAndActivity_produceNoRecordTypes() {
    #expect(HealthDataCategory.workouts.recordTypes == [])
    #expect(HealthDataCategory.activity.recordTypes == [])
  }

  @Test func test_noRecordType_isDoubleMapped() {
    let all = HealthDataCategory.allCases.flatMap(\.recordTypes)
    #expect(all.count == Set(all).count, "each RecordType is mapped by exactly one category")
  }
}
