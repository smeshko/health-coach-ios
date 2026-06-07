import APIClient
import CheckInRepository
import CoachCore
import Database
import DatabaseLive
import Dependencies
import DomainModels
import Foundation
import GRDB
import HealthKitClient
import PersistenceModels
import StrengthTestRepository
import SyncRepository
import WireModels
import XCTest

@testable import SyncRepositoryLive

final class SyncOrchestrationTests: XCTestCase {
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

  func test_sync_success_buildsPayload_advancesWatermark_storesServerTime() async throws {
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
    XCTAssertEqual(stubs.capturedRequest?.records.count, 1)
    XCTAssertNotNil(stubs.capturedRequest?.checkin)
    XCTAssertNotNil(stubs.capturedRequest?.strengthTest)
    // Mapped result.
    XCTAssertEqual(result.recordsUpserted, 3)
    XCTAssertEqual(result.serverTime, Date(timeIntervalSince1970: 5000))
    // Watermark advanced to the read instant + serverTime stored + strength-week marker set.
    let mark = try await watermark(db)
    XCTAssertEqual(mark?.anchor, anchorString(Self.now))
    XCTAssertEqual(mark?.serverTime, Date(timeIntervalSince1970: 5000))
    XCTAssertEqual(mark?.lastStrengthTestSyncedWeek, Self.currentWeek)
  }

  func test_sync_apiThrows_watermarkUnchanged() async throws {
    let db = try DatabaseClient.makeInMemory()
    // Seed an existing watermark so we can prove it is NOT modified.
    let seeded = SyncWatermarkRecord(anchor: "111.0", serverTime: Date(timeIntervalSince1970: 111))
    try await db.write { dbx in try seeded.save(dbx) }
    let stubs = SyncStubs(apiResult: .failure(.envelope(
      code: WireEnum(.internalError), message: "", detail: nil, status: 500
    )))

    do {
      _ = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }
      XCTFail("expected a thrown SyncError")
    } catch let error as SyncError {
      XCTAssertEqual(error, .serverError)
    }

    let mark = try await watermark(db)
    XCTAssertEqual(mark, seeded, "a failed POST must leave the watermark untouched")
  }

  func test_sync_zeroUpsert_succeeds_advancesWatermark() async throws {
    let db = try DatabaseClient.makeInMemory()
    let stubs = SyncStubs(apiResult: .success(syncResponse())) // all-zero counts

    let result = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }

    XCTAssertEqual(result.recordsUpserted, 0)
    XCTAssertEqual(result.workoutsUpserted, 0)
    let mark = try await watermark(db)
    XCTAssertEqual(mark?.anchor, anchorString(Self.now), "a zero-upsert 200 still advances the watermark")
  }

  func test_sync_unauthorized_propagatesAPIError() async throws {
    let db = try DatabaseClient.makeInMemory()
    let stubs = SyncStubs(apiResult: .failure(.unauthorized))

    do {
      _ = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }
      XCTFail("expected a thrown error")
    } catch let error as APIError {
      XCTAssertEqual(error, .unauthorized, "401 propagates as the raw APIError, not a SyncError")
    } catch {
      XCTFail("expected APIError.unauthorized, got \(error)")
    }
    let mark = try await watermark(db)
    XCTAssertNil(mark, "a 401 must not advance the watermark")
  }

  private func env(_ code: WireEnum<ErrorCode>, _ status: Int) -> APIError {
    .envelope(code: code, message: "", detail: nil, status: status)
  }

  func test_apiError_mapsToSyncError() {
    XCTAssertEqual(syncError(env(WireEnum(.validationError), 422)), .validationFailed)
    XCTAssertEqual(syncError(env(WireEnum(.internalError), 500)), .serverError)
    XCTAssertEqual(syncError(env(WireEnum(.briefGenerationFailed), 502)), .transient)
    XCTAssertEqual(syncError(env(WireEnum(.upstreamTimeout), 504)), .transient)
    XCTAssertEqual(syncError(env(WireEnum(.notFound), 404)), .transient)
    XCTAssertEqual(syncError(env(WireEnum(rawValue: "new_code"), 500)), .transient)
    XCTAssertEqual(syncError(.transport("offline")), .network)
    XCTAssertEqual(syncError(.decoding("bad")), .mappingFailed)
    XCTAssertEqual(syncError(.unexpectedStatus(418)), .transient)
  }

  func test_strengthTest_attachedOnlyWhenDue() async throws {
    // (a) Due: no marker, a test dated in the current week → attached + marker set.
    let dbDue = try DatabaseClient.makeInMemory()
    let dueStubs = SyncStubs(
      apiResult: .success(syncResponse()),
      strengthTest: DomainModels.StrengthTest(date: Self.now, maxPushups: 30, maxPullups: 8)
    )
    _ = try await run(stubs: dueStubs, database: dbDue) { try await SyncRepository.live.sync() }
    XCTAssertNotNil(dueStubs.capturedRequest?.strengthTest, "a current-week test with no marker is due")
    let dueMark = try await watermark(dbDue)
    XCTAssertEqual(dueMark?.lastStrengthTestSyncedWeek, Self.currentWeek)

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
    XCTAssertNil(syncedStubs.capturedRequest?.strengthTest, "already synced this week → omitted")

    // (c) Stale prior-week test: dated last week → omitted (never attach a stale value).
    let dbStale = try DatabaseClient.makeInMemory()
    let staleStubs = SyncStubs(
      apiResult: .success(syncResponse()),
      strengthTest: DomainModels.StrengthTest(
        date: Self.now.addingTimeInterval(-7 * 86400), maxPushups: 30, maxPullups: 8
      )
    )
    _ = try await run(stubs: staleStubs, database: dbStale) { try await SyncRepository.live.sync() }
    XCTAssertNil(staleStubs.capturedRequest?.strengthTest, "a prior-week test is not due this week")
  }

  func test_strengthTest_sentWithTodaysDate() async throws {
    // A test logged Monday (week 24), synced on Wednesday (same week): the gate passes on the test's
    // own date, but the payload must carry TODAY's date (Wednesday) — the server derives the ISO week.
    let db = try DatabaseClient.makeInMemory()
    let wednesday = Self.now.addingTimeInterval(2 * 86400) // still ISO week 24
    let mondayTest = DomainModels.StrengthTest(date: Self.now, maxPushups: 30, maxPullups: 8)
    let stubs = SyncStubs(apiResult: .success(syncResponse()), strengthTest: mondayTest)

    _ = try await run(stubs: stubs, database: db, now: wednesday) {
      try await SyncRepository.live.sync()
    }

    XCTAssertEqual(
      stubs.capturedRequest?.strengthTest?.date, WireCalendarDate(wednesday),
      "the strength test is sent dated today, not the day it was logged"
    )
    XCTAssertEqual(stubs.capturedRequest?.strengthTest?.maxPushups, 30, "the logged numbers are preserved")
  }

  func test_firstEverSync_usesBackfillAnchor() async throws {
    let db = try DatabaseClient.makeInMemory() // no watermark
    let stubs = SyncStubs(apiResult: .success(syncResponse()))

    _ = try await run(stubs: stubs, database: db) { try await SyncRepository.live.sync() }

    XCTAssertEqual(stubs.capturedSince, .distantPast, "first-ever sync reads from the backfill anchor")
    let mark = try await watermark(db)
    XCTAssertNotNil(mark, "the first sync creates the watermark row on success")
  }
}
