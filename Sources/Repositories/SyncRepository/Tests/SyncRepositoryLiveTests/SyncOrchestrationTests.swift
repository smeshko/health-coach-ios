import APIClient
import CoachCore
import CoachTestSupport
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import HealthKitClient
import LocalRepositories
import PersistenceModels
import SampleData
import SyncRepository
import Testing
import WireModels

@testable import SyncRepositoryLive

/// Stub clients for the sync orchestration tests. The API route is built on the shared
/// `APIClient.failing(overriding:)` factory + `CallRecorder` (Phase 11.6); the
/// HealthKit/CheckIn/StrengthTest builders are sync-specific and live here (their only consumer),
/// not in the shared API-stub factory.
final class SyncStubs: @unchecked Sendable {
  private let requestRecorder = CallRecorder<SyncRequest>()
  private let sinceRecorder = CallRecorder<Date>()

  let apiResult: Result<SyncResponse, APIError>
  let samples: HealthSampleSet
  let checkin: DomainModels.CheckIn?
  let strengthTest: DomainModels.StrengthTest?

  init(
    apiResult: Result<SyncResponse, APIError>,
    samples: HealthSampleSet = HealthSampleSet(),
    checkin: DomainModels.CheckIn? = nil,
    strengthTest: DomainModels.StrengthTest? = nil
  ) {
    self.apiResult = apiResult
    self.samples = samples
    self.checkin = checkin
    self.strengthTest = strengthTest
  }

  var capturedRequest: SyncRequest? { requestRecorder.lastArgument }
  var capturedSince: Date? { sinceRecorder.lastArgument }

  func healthKit() -> HealthKitClient {
    HealthKitClient(
      isHealthDataAvailable: { true },
      requestAuthorization: {},
      authorizationStatus: { [:] },
      deltaSamples: { [self] since in
        sinceRecorder.record(since)
        return samples
      }
    )
  }

  func api() -> APIClient {
    .failing(sync: { [self] request in
      requestRecorder.record(request)
      return try apiResult.get()
    })
  }

  func checkInRepository() -> CheckInRepository {
    CheckInRepository(save: { _ in }, current: { [self] _ in checkin })
  }

  func strengthTestRepository() -> StrengthTestRepository {
    StrengthTestRepository(save: { _ in }, current: { [self] _ in strengthTest })
  }
}

/// A canned successful response with caller-supplied counts (defaults all-zero).
func syncResponse(
  recordsUpserted: Int = 0,
  recordsDuplicate: Int = 0,
  workoutsUpserted: Int = 0,
  activityDaysUpserted: Int = 0,
  checkinSaved: Bool = false,
  strengthTestSaved: Bool = false,
  serverTime: Date = Date(timeIntervalSince1970: 5000)
) -> SyncResponse {
  SyncResponse(
    recordsUpserted: recordsUpserted,
    recordsDuplicate: recordsDuplicate,
    workoutsUpserted: workoutsUpserted,
    activityDaysUpserted: activityDaysUpserted,
    checkinSaved: checkinSaved,
    strengthTestSaved: strengthTestSaved,
    serverTime: serverTime
  )
}

struct SyncOrchestrationTests {
  /// 2026-06-08 ~09:00 Europe/Sofia — a Monday in ISO week 24.
  private static let now = Date(timeIntervalSince1970: 1_780_898_400)
  private static let currentWeek = ISOWeek(year: 2026, week: 24)

  private func run<T>(
    stubs: SyncStubs,
    database: DatabaseClient,
    now: Date = SyncOrchestrationTests.now,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(now)
      $0.healthKitClient = stubs.healthKit()
      $0.apiClient = stubs.api()
      $0.database = database
      $0.checkInRepository = stubs.checkInRepository()
      $0.strengthTestRepository = stubs.strengthTestRepository()
    } operation: {
      try await work()
    }
  }

  private func watermark(_ database: DatabaseClient) async throws -> SyncWatermarkRecord? {
    try await database.read { db in try SyncWatermarkRecord.fetchOne(db, key: 1) }
  }

  @Test func test_sync_success_buildsPayload_advancesWatermark_storesServerTime() async throws {
    let db = try DatabaseClient.makeInMemory()
    let checkin = DomainModels.CheckIn(date: Self.now, giSymptoms: false, kneePain: 1, illness: false)
    let strength = DomainModels.StrengthTest(date: Self.now, maxPushups: 30, maxPullups: 8)
    let stubs = SyncStubs(
      apiResult: .success(syncResponse(recordsUpserted: 3, checkinSaved: true, strengthTestSaved: true)),
      samples: HealthSampleSet(records: [
        HealthRecordPayload(uuid: "u", type: .heartRate, start: Self.now, end: Self.now, value: 60),
      ]),
      checkin: checkin,
      strengthTest: strength
    )

    let result = try await run(stubs: stubs, database: db) {
      try await SyncRepository.live.sync()
    }

    // Request members assembled from the inputs.
    #expect(stubs.capturedRequest?.records.count == 1)
    #expect(stubs.capturedRequest?.checkin != nil)
    #expect(stubs.capturedRequest?.strengthTest != nil)
    // Mapped result.
    #expect(result.recordsUpserted == 3)
    #expect(result.serverTime == Date(timeIntervalSince1970: 5000))
    // Watermark advanced to the read instant + serverTime stored + strength-week marker set.
    let mark = try await watermark(db)
    #expect(mark?.anchor == anchorString(Self.now))
    #expect(mark?.serverTime == Date(timeIntervalSince1970: 5000))
    #expect(mark?.lastStrengthTestSyncedWeek == Self.currentWeek)
  }

  @Test func test_sync_apiThrows_watermarkUnchanged() async throws {
    let db = try DatabaseClient.makeInMemory()
    // Seed an existing watermark so we can prove it is NOT modified.
    let seeded = SyncWatermarkRecord(anchor: "111.0", serverTime: Date(timeIntervalSince1970: 111))
    try await db.write { dbx in try seeded.save(dbx) }
    let stubs = SyncStubs(apiResult: .failure(.envelope(
      code: .internalError, message: "", detail: nil, status: 500
    )))

    do {
      _ = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }
      Issue.record("expected a thrown SyncError")
    } catch let error as SyncError {
      #expect(error == .serverError)
    }

    let mark = try await watermark(db)
    #expect(mark == seeded, "a failed POST must leave the watermark untouched")
  }

  @Test func test_sync_zeroUpsert_succeeds_advancesWatermark() async throws {
    let db = try DatabaseClient.makeInMemory()
    let stubs = SyncStubs(apiResult: .success(syncResponse())) // all-zero counts

    let result = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }

    #expect(result.recordsUpserted == 0)
    #expect(result.workoutsUpserted == 0)
    let mark = try await watermark(db)
    #expect(mark?.anchor == anchorString(Self.now), "a zero-upsert 200 still advances the watermark")
  }

  @Test func test_sync_unauthorized_propagatesAPIError() async throws {
    let db = try DatabaseClient.makeInMemory()
    let stubs = SyncStubs(apiResult: .failure(.unauthorized))

    do {
      _ = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }
      Issue.record("expected a thrown error")
    } catch let error as APIError {
      #expect(error == .unauthorized, "401 propagates as the raw APIError, not a SyncError")
    } catch {
      Issue.record("expected APIError.unauthorized, got \(error)")
    }
    let mark = try await watermark(db)
    #expect(mark == nil, "a 401 must not advance the watermark")
  }

  private func env(_ code: ErrorCode, _ status: Int) -> APIError {
    .envelope(code: code, message: "", detail: nil, status: status)
  }

  @Test func test_sync_envelopeUnauthorized_propagatesAPIError() async throws {
    // An envelope-form 401 must ALSO be intercepted and re-thrown raw — `syncError` would otherwise
    // map it to `.transient`, silently swallowing the 401.
    let db = try DatabaseClient.makeInMemory()
    let stubs = SyncStubs(apiResult: .failure(
      .envelope(code: .unauthorized, message: "", detail: nil, status: 401)
    ))

    do {
      _ = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }
      Issue.record("expected a thrown error")
    } catch let error as APIError {
      #expect(isUnauthorized(error), "envelope 401 propagates as the raw APIError")
    } catch {
      Issue.record("expected APIError, got \(error)")
    }
    let mark = try await watermark(db)
    #expect(mark == nil, "an envelope 401 must not advance the watermark")
  }

  @Test func test_apiError_mapsToSyncError() {
    #expect(syncError(env(.validationError, 422)) == .validationFailed)
    #expect(syncError(env(.internalError, 500)) == .serverError)
    #expect(syncError(env(.briefGenerationFailed, 502)) == .transient)
    #expect(syncError(env(.upstreamTimeout, 504)) == .transient)
    #expect(syncError(env(.notFound, 404)) == .transient)
    #expect(syncError(.transport("offline")) == .network)
    #expect(syncError(.decoding("bad")) == .mappingFailed)
    #expect(syncError(.unexpectedStatus(418)) == .transient)
  }

  @Test func test_strengthTest_attachedOnlyWhenDue() async throws {
    // (a) Due: no marker, a test dated in the current week → attached + marker set.
    let dbDue = try DatabaseClient.makeInMemory()
    let dueStubs = SyncStubs(
      apiResult: .success(syncResponse()),
      strengthTest: DomainModels.StrengthTest(date: Self.now, maxPushups: 30, maxPullups: 8)
    )
    _ = try await run(stubs: dueStubs, database: dbDue) { try await SyncRepository.live.sync() }
    #expect(dueStubs.capturedRequest?.strengthTest != nil, "a current-week test with no marker is due")
    let dueMark = try await watermark(dbDue)
    #expect(dueMark?.lastStrengthTestSyncedWeek == Self.currentWeek)

    // (b) Already synced this week: marker == current week → omitted.
    let dbSynced = try DatabaseClient.makeInMemory()
    try await dbSynced.write { dbx in
      try SyncWatermarkRecord(
        anchor: "1.0", serverTime: Date(timeIntervalSince1970: 1), lastStrengthTestSyncedWeek: Self.currentWeek
      ).save(dbx)
    }
    let syncedStubs = SyncStubs(
      apiResult: .success(syncResponse()),
      strengthTest: DomainModels.StrengthTest(date: Self.now, maxPushups: 30, maxPullups: 8)
    )
    _ = try await run(stubs: syncedStubs, database: dbSynced) { try await SyncRepository.live.sync() }
    #expect(syncedStubs.capturedRequest?.strengthTest == nil, "already synced this week → omitted")
    let syncedMark = try await watermark(dbSynced)
    #expect(
      syncedMark?.lastStrengthTestSyncedWeek == Self.currentWeek,
      "the marker is preserved when no test is attached (not nilled)"
    )

    // (c) Stale prior-week test: dated last week → omitted (never attach a stale value).
    let dbStale = try DatabaseClient.makeInMemory()
    let staleStubs = SyncStubs(
      apiResult: .success(syncResponse()),
      strengthTest: DomainModels.StrengthTest(
        date: Self.now.addingTimeInterval(-7 * 86400), maxPushups: 30, maxPullups: 8
      )
    )
    _ = try await run(stubs: staleStubs, database: dbStale) { try await SyncRepository.live.sync() }
    #expect(staleStubs.capturedRequest?.strengthTest == nil, "a prior-week test is not due this week")
  }

  @Test func test_strengthTest_sentWithTodaysDate() async throws {
    // A test logged Monday (week 24), synced on Wednesday (same week): the gate passes on the test's
    // own date, but the payload must carry TODAY's date (Wednesday) — the server derives the ISO week.
    let db = try DatabaseClient.makeInMemory()
    let wednesday = Self.now.addingTimeInterval(2 * 86400) // still ISO week 24
    let mondayTest = DomainModels.StrengthTest(date: Self.now, maxPushups: 30, maxPullups: 8)
    let stubs = SyncStubs(apiResult: .success(syncResponse()), strengthTest: mondayTest)

    _ = try await run(stubs: stubs, database: db, now: wednesday) {
      try await SyncRepository.live.sync()
    }

    #expect(
      stubs.capturedRequest?.strengthTest?.date == wednesday,
      "the strength test is sent dated today, not the day it was logged"
    )
    #expect(stubs.capturedRequest?.strengthTest?.maxPushups == 30, "the logged numbers are preserved")
  }

  @Test func test_firstEverSync_usesBackfillAnchor() async throws {
    let db = try DatabaseClient.makeInMemory() // no watermark
    let stubs = SyncStubs(apiResult: .success(syncResponse()))

    _ = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }

    #expect(stubs.capturedSince == .distantPast, "first-ever sync reads from the backfill anchor")
    let mark = try await watermark(db)
    #expect(mark != nil, "the first sync creates the watermark row on success")
  }

  // MARK: - Partial-input asymmetry (audit gap #15)

  /// A throwing `checkInRepository.current` degrades to nil (`try?`) — the sync still SUCCEEDS, sending
  /// no check-in. Pins the documented optional-check-in behavior.
  @Test func test_sync_checkInReadThrows_degradesToNil_syncSucceeds() async throws {
    let db = try DatabaseClient.makeInMemory()
    let stubs = SyncStubs(apiResult: .success(syncResponse()))

    let result = try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.healthKitClient = stubs.healthKit()
      $0.apiClient = stubs.api()
      $0.database = db
      $0.checkInRepository = CheckInRepository(save: { _ in }, current: { _ in throw StubReadError() })
      $0.strengthTestRepository = stubs.strengthTestRepository()
    } operation: {
      try await SyncRepository.live.sync()
    }

    #expect(result.recordsUpserted == 0, "sync succeeds despite the check-in read failing")
    #expect(stubs.capturedRequest?.checkin == nil, "a failed check-in read sends no check-in (try? → nil)")
    let mark = try await watermark(db)
    #expect(mark != nil, "the watermark still advances on a successful sync")
  }

  /// ASYMMETRY: a throwing `strengthTestRepository.current` is NOT swallowed — it ABORTS the whole sync
  /// (the read is `try`, not `try?`). Pins the asymmetry vs the check-in half above (documented, not
  /// fixed — the strength read is on the due-gate path and a failure there is treated as fatal).
  @Test func test_sync_strengthReadThrows_abortsSync() async throws {
    let db = try DatabaseClient.makeInMemory()
    let stubs = SyncStubs(apiResult: .success(syncResponse()))

    let work: @Sendable () async throws -> Void = {
      _ = try await withDependencies {
        $0.useEuropeSofia()
        $0.date = .constant(Self.now)
        $0.healthKitClient = stubs.healthKit()
        $0.apiClient = stubs.api()
        $0.database = db
        $0.checkInRepository = stubs.checkInRepository()
        $0.strengthTestRepository = StrengthTestRepository(save: { _ in }, current: { _ in throw StubReadError() })
      } operation: {
        try await SyncRepository.live.sync()
      }
    }

    await #expect(throws: StubReadError.self) { try await work() }
    let mark = try await watermark(db)
    #expect(mark == nil, "an aborted sync must not advance the watermark")
  }

  /// The routing-used `SyncRepository.mock` must stay **dependency-free** (no HealthKit/APIClient/
  /// Database) and return the canned `SampleData` result. Injecting NO live deps here means a future
  /// change that made the mock resolve `@Dependency` would crash on an unimplemented dependency
  /// (review #2.3 — the no-live-deps guard the deleted `MockTests` carried).
  @Test func test_mock_returnsCannedResult_withoutResolvingLiveDeps() async throws {
    let result = try await SyncRepository.mock(scenario: .success).sync()
    let expected = try syncResult(SampleData.syncResponse())
    #expect(result == expected)
  }
}

private struct StubReadError: Error {}
