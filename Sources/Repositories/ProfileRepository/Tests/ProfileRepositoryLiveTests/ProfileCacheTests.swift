import APIClient
import CoachTestSupport
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import LogClient
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

  /// Seed the singleton row with garbage `body` bytes — the memberwise init bypasses the domain
  /// encoder, so `toDomain()` throws a `DecodingError` on read (Phase 19.2 TASK-002).
  private func seedCorruptProfile(_ database: DatabaseClient) async throws {
    try await database.write { db in
      try ProfileRecord(id: 1, constitutionVersion: "vX", body: Data("garbage".utf8)).save(db)
    }
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

  /// Phase 19.2 TASK-002 (a): an undecodable cached profile degrades to a fresh fetch — the corrupt
  /// row is deleted, the network fetch persists a replacement, and the second call is a plain cache
  /// hit with zero further network. Exactly one degradation notice lands on `.http`.
  @Test func test_corruptCachedProfile_workingAPI_refetchesAndReplaces() async throws {
    let db = try DatabaseClient.makeInMemory()
    try await seedCorruptProfile(db)
    let fixture = try SampleData.profile()
    let api = ProfileAPIStub(result: .success(fixture.dto))
    let recorder = LogRecorder()

    let (first, second) = try await withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      let first = try await run(api: api, database: db) { try await Self.makeRepo().profile() }
      let second = try await run(api: api, database: db) { try await Self.makeRepo().profile() }
      return (first, second)
    }

    #expect(first == fixture.domain, "the corrupt row is a miss — the fresh fetch is returned")
    #expect(second == fixture.domain, "the replaced row decodes — a plain cache hit")
    #expect(api.callCount == 1, "the replaced row serves from cache — no second network call")
    let stored = try await db.read { dbx in try ProfileRecord.fetchOne(dbx, key: 1) }
    try #expect(stored?.toDomain() == fixture.domain, "the corrupt row is replaced under id 1")
    let notices = recorder.entries.filter { $0.level == .notice && $0.category == .http }
    #expect(notices.count == 1, "exactly one decode-degradation notice on .http")
  }

  /// Phase 19.2 TASK-002 (b): corrupt row + failing API surfaces the ordinary recoverable
  /// `.fetchFailed` (never a raw `DecodingError`); the corrupt row is already gone, so the next call
  /// is a clean miss that succeeds once the API does — no lingering re-brick.
  @Test func test_corruptCachedProfile_failingAPI_throwsFetchFailed_thenRecovers() async throws {
    let db = try DatabaseClient.makeInMemory()
    try await seedCorruptProfile(db)
    let failingAPI = ProfileAPIStub(result: .failure(.transport("offline")))

    do {
      _ = try await run(api: failingAPI, database: db) { try await Self.makeRepo().profile() }
      Issue.record("expected ProfileRepositoryError")
    } catch let error as ProfileRepositoryError {
      guard case .fetchFailed = error else {
        Issue.record("expected .fetchFailed, got \(error)")
        return
      }
    }

    let count = try await db.read { dbx in try ProfileRecord.fetchCount(dbx) }
    #expect(count == 0, "the corrupt row is deleted even when the refetch fails")

    let fixture = try SampleData.profile()
    let workingAPI = ProfileAPIStub(result: .success(fixture.dto))
    let recovered = try await run(api: workingAPI, database: db) { try await Self.makeRepo().profile() }
    #expect(recovered == fixture.domain, "the next call is a clean miss that succeeds")
    #expect(workingAPI.callCount == 1)
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
