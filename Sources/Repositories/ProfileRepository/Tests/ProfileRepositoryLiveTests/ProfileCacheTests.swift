import APIClient
import CoachTestSupport
import Database
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

/// A recording profile-route stub built on the shared `APIClient.failing(overriding:)` factory
/// (Phase 11.6 — replaces the deleted per-target `StubProfileAPI`). Counts `profile()` calls via the
/// shared `CallRecorder`; the profile route serves a canned `ProfileResponse` or throws.
struct ProfileAPIStub {
  private let recorder = CallRecorder<Void>()
  let result: Result<ProfileResponse, APIError>

  var callCount: Int { recorder.count }

  func makeClient() -> APIClient {
    .failing(profile: {
      recorder.record(())
      return try result.get()
    })
  }
}

struct ProfileCacheTests {
  private func run<T>(
    api: ProfileAPIStub,
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

  /// A fresh live repository. `static` so the `@Sendable` work closures don't capture the test case.
  private static func makeRepo() -> ProfileRepository {
    .live()
  }

  @Test func test_cacheMiss_fetchesAndCaches() async throws {
    let db = try DatabaseClient.makeInMemory()
    let fixture = try SampleData.profile()
    let api = ProfileAPIStub(result: .success(fixture.dto))

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
    let api = ProfileAPIStub(result: .failure(.unexpectedStatus(0))) // throws if called; callCount==0 is the real guard

    let result = try await run(api: api, database: db) {
      try await Self.makeRepo().profile()
    }

    #expect(result == fixture.domain)
    #expect(api.callCount == 0, "a cached profile serves without a network call")
  }

  @Test func test_apiError_mapsToProfileError() async throws {
    let db = try DatabaseClient.makeInMemory() // empty → a miss forces the (failing) fetch
    let api = ProfileAPIStub(result: .failure(.transport("offline")))

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

  /// The routing-used `ProfileRepository.mock` must stay **dependency-free** (no live API/DB) and
  /// return the canned `SampleData` profile + zones. Injecting NO live deps here means a future change
  /// that made the mock resolve `@Dependency` would crash on an unimplemented dependency, and a wrong
  /// canned value / dropped zones would fail the equality (review #3 — parallel to the SyncRepository
  /// mock smoke; the deleted interface target was its only exerciser).
  @Test func test_mock_returnsCannedProfileAndZones_withoutLiveDeps() async throws {
    let expected = try SampleData.profile().domain
    let profile = try await ProfileRepository.mock(scenario: .profile).profile()
    let zones = try await ProfileRepository.mock(scenario: .profile).zones()
    #expect(profile == expected)
    #expect(zones == expected.zones)
  }
}
