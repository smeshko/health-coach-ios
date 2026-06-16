import APIClient
import CoachTestSupport
import Database
import Dependencies
import Foundation
import PersistenceModels
import SyncRepository
import Testing

@testable import SyncRepositoryLive

/// `SyncRepository.lastSync()` is a read-only watermark read (Phase 10.2 DECISIONS #1): it returns the
/// persisted `serverTime` via `Database` with **no** network round-trip, so a passive surface (Settings)
/// can show the last-sync time without triggering a sync.
struct SyncLastSyncTests {
  @Test func test_lastSync_returnsStoredServerTime_noNetwork() async throws {
    let db = try DatabaseClient.makeInMemory()
    let stored = Date(timeIntervalSince1970: 1_780_000_000)
    try await db.write { dbx in
      try SyncWatermarkRecord(anchor: "1.0", serverTime: stored).save(dbx)
    }
    // A failing APIClient whose `sync` records (and throws) if invoked — proving lastSync never POSTs.
    let syncCalls = LockIsolated(0)
    let api = APIClient.failing(sync: { _ in
      syncCalls.withValue { $0 += 1 }
      throw APIError.unexpectedStatus(0)
    })

    let result = try await withDependencies {
      $0.database = db
      $0.apiClient = api
    } operation: {
      try await SyncRepository.live.lastSync()
    }

    #expect(result == stored)
    #expect(syncCalls.value == 0, "lastSync must not call the network")
  }

  @Test func test_lastSync_nilWhenNoWatermark() async throws {
    let db = try DatabaseClient.makeInMemory()
    let result = try await withDependencies {
      $0.database = db
      $0.apiClient = .failing()
    } operation: {
      try await SyncRepository.live.lastSync()
    }
    #expect(result == nil)
  }

  @Test func test_testValue_lastSync_returnsCanned() async throws {
    let result = try await SyncRepository.testValue.lastSync()
    #expect(result == Date(timeIntervalSince1970: 1_780_898_400))
  }
}
