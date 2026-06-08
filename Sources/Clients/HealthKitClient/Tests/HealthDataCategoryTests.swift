@testable import HealthKitClient
import WireModels
import XCTest

final class HealthDataCategoryTests: XCTestCase {
  func test_categoryMapping_coversEveryWireRecordType_exactly() {
    let mapped = Set(HealthDataCategory.allCases.flatMap(\.recordTypes))
    // `RecordType` here is the clean, CaseIterable wire enum (Phase 2.1 put the unknown-tolerance in
    // the generic `WireEnum<>` box, not on `RecordType`), so its `allCases` is the source of truth.
    XCTAssertEqual(mapped, Set(RecordType.allCases))
    XCTAssertEqual(mapped.count, 24, "the wire RecordType set has 24 values")
  }

  func test_workoutsAndActivity_produceNoRecordTypes() {
    XCTAssertEqual(HealthDataCategory.workouts.recordTypes, [])
    XCTAssertEqual(HealthDataCategory.activity.recordTypes, [])
  }

  func test_noRecordType_isDoubleMapped() {
    let all = HealthDataCategory.allCases.flatMap(\.recordTypes)
    XCTAssertEqual(all.count, Set(all).count, "each RecordType is mapped by exactly one category")
  }
}
