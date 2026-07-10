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

  private func seedProfile(
    _ database: DatabaseClient,
    _ domain: DomainModels.Profile,
    syncServerTime: Date? = nil
  ) async throws {
    try await database.write { db in
      try ProfileRecord(domain: domain, syncServerTime: syncServerTime).save(db)
    }
  }

  /// Seed (or overwrite) the singleton sync watermark — advancing `serverTime` models a successful
  /// sync completing (Phase 19.2 TASK-003).
  private func seedWatermark(_ database: DatabaseClient, serverTime: Date) async throws {
    try await database.write { db in
      try SyncWatermarkRecord(anchor: "anchor-token", serverTime: serverTime).save(db)
    }
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

  /// Also Phase 19.2 TASK-003 (e): a never-synced DB (no watermark row) + an unstamped cached row
  /// is fresh — `nil == nil` — so it serves from cache with zero network.
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

  /// Phase 19.2 TASK-003 (a): a stamped row whose stamp equals the current watermark `serverTime`
  /// is fresh — cache serve, zero network (the fresh-hit path keeps its pre-19.2 cost).
  @Test func test_freshStamp_matchingWatermark_cacheServes_noNetwork() async throws {
    let db = try DatabaseClient.makeInMemory()
    let syncTime = Date(timeIntervalSince1970: 1_000)
    let fixture = try SampleData.profile()
    try await seedWatermark(db, serverTime: syncTime)
    try await seedProfile(db, fixture.domain, syncServerTime: syncTime)
    let api = ProfileAPIStub(result: .failure(.unexpectedStatus(0))) // callCount==0 is the real guard

    let result = try await run(api: api, database: db) {
      try await Self.makeRepo().profile()
    }

    #expect(result == fixture.domain)
    #expect(api.callCount == 0, "stamp == watermark serverTime → fresh, no network")
  }

  /// Phase 19.2 TASK-003 (b): a successful sync advances the watermark `serverTime` → the next
  /// `profile()` refetches exactly once, returns + persists the recomputed values restamped with
  /// the new `serverTime`, and the call after that is a plain cache serve again.
  @Test func test_watermarkAdvances_refetchesOnceAndRestamps_thenSteadyState() async throws {
    let db = try DatabaseClient.makeInMemory()
    let oldSync = Date(timeIntervalSince1970: 1_000)
    let newSync = Date(timeIntervalSince1970: 2_000)
    let fixture = try SampleData.profile()
    var recomputed = fixture.dto
    recomputed.thresholds.maxHr += 5 // the server-side constants recompute
    try await seedWatermark(db, serverTime: oldSync)
    try await seedProfile(db, fixture.domain, syncServerTime: oldSync)
    // A successful sync advances the watermark; the row's old stamp now differs.
    try await seedWatermark(db, serverTime: newSync)
    let api = ProfileAPIStub(result: .success(recomputed))

    let (afterSync, steadyState) = try await run(api: api, database: db) {
      let afterSync = try await Self.makeRepo().profile()
      let steadyState = try await Self.makeRepo().profile()
      return (afterSync, steadyState)
    }

    #expect(afterSync == recomputed, "the recomputed constants reach the device")
    #expect(steadyState == recomputed, "the restamped row is fresh again")
    #expect(api.callCount == 1, "exactly one refetch per watermark advance")
    let stored = try await db.read { dbx in try ProfileRecord.fetchOne(dbx, key: 1) }
    #expect(stored?.syncServerTime == newSync, "the row is restamped with the new serverTime")
    let storedDomain = try stored?.toDomain()
    #expect(storedDomain == recomputed, "the recomputed profile is persisted")
  }

  /// Phase 19.2 TASK-003 (c) / D3: stale stamp + failing refetch stale-serves the decoded cached
  /// values — freshness never buys an outage; no throw, availability unchanged.
  @Test func test_staleStamp_refetchFails_staleServesCachedValues() async throws {
    let db = try DatabaseClient.makeInMemory()
    try await seedWatermark(db, serverTime: Date(timeIntervalSince1970: 2_000))
    let fixture = try SampleData.profile()
    try await seedProfile(db, fixture.domain, syncServerTime: Date(timeIntervalSince1970: 1_000))
    let api = ProfileAPIStub(result: .failure(.transport("offline")))

    let result = try await run(api: api, database: db) {
      try await Self.makeRepo().profile()
    }

    #expect(result == fixture.domain, "the cached values are served, not an error")
    #expect(api.callCount == 1, "the refetch was attempted before stale-serving")
  }

  /// Phase 19.2 TASK-003 (d): a pre-upgrade row (NULL stamp — migration v5 backfill) is stale
  /// exactly once when a watermark exists: one refetch restamps it, then steady-state cache serves.
  @Test func test_nullStamp_preUpgradeRow_staleExactlyOnce() async throws {
    let db = try DatabaseClient.makeInMemory()
    let syncTime = Date(timeIntervalSince1970: 1_000)
    try await seedWatermark(db, serverTime: syncTime)
    let fixture = try SampleData.profile()
    try await seedProfile(db, fixture.domain, syncServerTime: nil) // the pre-v5 row shape
    let api = ProfileAPIStub(result: .success(fixture.dto))

    let (first, second) = try await run(api: api, database: db) {
      let first = try await Self.makeRepo().profile()
      let second = try await Self.makeRepo().profile()
      return (first, second)
    }

    #expect(first == fixture.domain)
    #expect(second == fixture.domain)
    #expect(api.callCount == 1, "the NULL stamp is stale exactly once, then steady state")
    let stored = try await db.read { dbx in try ProfileRecord.fetchOne(dbx, key: 1) }
    #expect(stored?.syncServerTime == syncTime, "the refetch stamps the row")
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
