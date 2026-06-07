import APIClient
import Database
import DatabaseLive
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import ProfileRepository
import SampleData
import WireModels
import XCTest

@testable import ProfileRepositoryLive

final class ProfileCacheTests: XCTestCase {
  private func run<T>(
    api: StubProfileAPI,
    database: DatabaseClient,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.apiClient = api.makeClient()
      $0.database = database
    } operation: {
      try await work()
    }
  }

  private func seedProfile(_ database: DatabaseClient, _ domain: DomainModels.Profile) async throws {
    try await database.write { db in try ProfileRecord(domain: domain).save(db) }
  }

  func test_cacheMiss_fetchesAndCaches() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    let api = StubProfileAPI(result: .success(fixture.dto))

    let result = try await run(api: api, database: db) {
      try await ProfileRepository.liveValue.profile()
    }

    XCTAssertEqual(result, fixture.domain)
    XCTAssertEqual(api.callCount, 1)
    let count = try await db.read { dbx in try ProfileRecord.fetchCount(dbx) }
    XCTAssertEqual(count, 1, "the fetched profile must be cached")
  }

  func test_cacheHit_noNetwork() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    try await seedProfile(db, fixture.domain)
    let api = StubProfileAPI(result: .failure(.unexpectedStatus(0))) // would trap if called via .get()

    let result = try await run(api: api, database: db) {
      try await ProfileRepository.liveValue.profile()
    }

    XCTAssertEqual(result, fixture.domain)
    XCTAssertEqual(api.callCount, 0, "a cached profile serves without a network call")
  }

  func test_refresh_overwrites() async throws {
    let db = try DatabaseClient.makeInMemory()
    var stale = try SampleData.profile().domain
    stale.athlete.age = 99 // a distinguishable stale cached value
    try await seedProfile(db, stale)
    let fixture = try SampleData.profile()
    let api = StubProfileAPI(result: .success(fixture.dto))

    let result = try await run(api: api, database: db) {
      try await ProfileRepository.liveValue.refresh()
    }

    XCTAssertEqual(result, fixture.domain, "refresh returns the fresh fetched profile")
    XCTAssertEqual(api.callCount, 1)
    let stored = try await db.read { dbx in try ProfileRecord.fetchOne(dbx, key: 1)?.toDomain() }
    XCTAssertEqual(stored, fixture.domain, "the cached record is overwritten")
  }

  func test_apiError_mapsToProfileError() async throws {
    let db = try DatabaseClient.makeInMemory() // empty → a miss forces the (failing) fetch
    let api = StubProfileAPI(result: .failure(.transport("offline")))

    do {
      _ = try await run(api: api, database: db) { try await ProfileRepository.liveValue.profile() }
      XCTFail("expected ProfileRepositoryError")
    } catch let error as ProfileRepositoryError {
      guard case .fetchFailed = error else { return XCTFail("expected .fetchFailed, got \(error)") }
    }
  }

  func test_apiError_cachedProfileStillServes() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    try await seedProfile(db, fixture.domain)
    let api = StubProfileAPI(result: .failure(.transport("offline")))

    // Cache-first: profile() serves the cache without attempting the (failing) fetch.
    let result = try await run(api: api, database: db) {
      try await ProfileRepository.liveValue.profile()
    }
    XCTAssertEqual(result, fixture.domain)
    XCTAssertEqual(api.callCount, 0)
  }
}
