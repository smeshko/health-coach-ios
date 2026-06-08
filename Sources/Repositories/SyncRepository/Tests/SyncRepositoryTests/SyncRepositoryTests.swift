import Dependencies
import DomainModels
import Foundation
import XCTest

@testable import SyncRepository

final class SyncRepositoryTests: XCTestCase {
  func test_testValue_returnsCannedResult() async throws {
    let result = try await SyncRepository.testValue.sync()
    XCTAssertEqual(result.recordsUpserted, 0)
    XCTAssertEqual(result.recordsDuplicate, 0)
    XCTAssertFalse(result.checkinSaved)
    XCTAssertEqual(result.serverTime, Date(timeIntervalSince1970: 0))
  }

  func test_syncResult_isEquatable() {
    let time = Date(timeIntervalSince1970: 100)
    let first = SyncResult(
      recordsUpserted: 1, recordsDuplicate: 2, workoutsUpserted: 3,
      activityDaysUpserted: 4, checkinSaved: true, strengthTestSaved: false, serverTime: time
    )
    let second = SyncResult(
      recordsUpserted: 1, recordsDuplicate: 2, workoutsUpserted: 3,
      activityDaysUpserted: 4, checkinSaved: true, strengthTestSaved: false, serverTime: time
    )
    XCTAssertEqual(first, second)
  }

  func test_syncError_isEquatable() {
    XCTAssertEqual(SyncError.transient, SyncError.transient)
    XCTAssertNotEqual(SyncError.transient, SyncError.serverError)
  }
}
