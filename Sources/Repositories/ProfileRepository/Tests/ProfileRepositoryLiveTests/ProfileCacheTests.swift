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
import Testing
import WireModels

@testable import ProfileRepositoryLive

struct ProfileCacheTests {
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

  /// A live repository over a fresh recompute stream — isolates each test from the process-wide
  /// `liveValue` stream. `static` so the `@Sendable` work closures don't capture the test case.
  private static func makeRepo() -> ProfileRepository {
    .live(recompute: RecomputeStream())
  }

  @Test func test_cacheMiss_fetchesAndCaches() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    let api = StubProfileAPI(result: .success(fixture.dto))

    let result = try await run(api: api, database: db) {
      try await Self.makeRepo().profile()
    }

    #expect(result == fixture.domain)
    #expect(api.callCount == 1)
    let count = try await db.read { dbx in try ProfileRecord.fetchCount(dbx) }
    #expect(count == 1, "the fetched profile must be cached")
  }

  @Test func test_cacheHit_noNetwork() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    try await seedProfile(db, fixture.domain)
    let api = StubProfileAPI(result: .failure(.unexpectedStatus(0))) // throws if called; callCount==0 is the real guard

    let result = try await run(api: api, database: db) {
      try await Self.makeRepo().profile()
    }

    #expect(result == fixture.domain)
    #expect(api.callCount == 0, "a cached profile serves without a network call")
  }

  @Test func test_refresh_overwrites() async throws {
    let db = try DatabaseClient.makeInMemory()
    var stale = try SampleData.profile().domain
    stale.athlete.age = 99 // a distinguishable stale cached value
    try await seedProfile(db, stale)
    let fixture = try SampleData.profile()
    let api = StubProfileAPI(result: .success(fixture.dto))

    let result = try await run(api: api, database: db) {
      try await Self.makeRepo().refresh()
    }

    #expect(result == fixture.domain, "refresh returns the fresh fetched profile")
    #expect(api.callCount == 1)
    let stored = try await db.read { dbx in try ProfileRecord.fetchOne(dbx, key: 1)?.toDomain() }
    #expect(stored == fixture.domain, "the cached record is overwritten")
  }

  @Test func test_apiError_mapsToProfileError() async throws {
    let db = try DatabaseClient.makeInMemory() // empty → a miss forces the (failing) fetch
    let api = StubProfileAPI(result: .failure(.transport("offline")))

    do {
      _ = try await run(api: api, database: db) { try await Self.makeRepo().profile() }
      Issue.record("expected ProfileRepositoryError")
    } catch let error as ProfileRepositoryError {
      guard case .fetchFailed = error else {
        Issue.record("expected .fetchFailed, got \(error)")
        return
      }
    }
  }

  @Test func test_apiError_cachedProfileStillServes() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    try await seedProfile(db, fixture.domain)
    let api = StubProfileAPI(result: .failure(.transport("offline")))

    // Cache-first: profile() serves the cache without attempting the (failing) fetch.
    let result = try await run(api: api, database: db) {
      try await Self.makeRepo().profile()
    }
    #expect(result == fixture.domain)
    #expect(api.callCount == 0)
  }
}
