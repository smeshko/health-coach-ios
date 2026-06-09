import Dependencies
import DomainModels
import Foundation
import Testing

@testable import SyncRepository

struct SyncRepositoryTests {
  @Test func test_testValue_returnsCannedResult() async throws {
    let result = try await SyncRepository.testValue.sync()
    #expect(result.recordsUpserted == 0)
    #expect(result.recordsDuplicate == 0)
    #expect(!result.checkinSaved)
    #expect(result.serverTime == Date(timeIntervalSince1970: 0))
  }

  @Test func test_syncResult_isEquatable() {
    let time = Date(timeIntervalSince1970: 100)
    let first = SyncResult(
      recordsUpserted: 1, recordsDuplicate: 2, workoutsUpserted: 3,
      activityDaysUpserted: 4, checkinSaved: true, strengthTestSaved: false, serverTime: time
    )
    let second = SyncResult(
      recordsUpserted: 1, recordsDuplicate: 2, workoutsUpserted: 3,
      activityDaysUpserted: 4, checkinSaved: true, strengthTestSaved: false, serverTime: time
    )
    #expect(first == second)
  }

  @Test func test_syncError_isEquatable() {
    #expect(SyncError.transient == SyncError.transient)
    #expect(SyncError.transient != SyncError.serverError)
  }
}
