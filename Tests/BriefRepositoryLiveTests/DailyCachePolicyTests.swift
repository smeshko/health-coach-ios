import APIClient
import BriefRepository
import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import SampleData
import WireModels
import XCTest

import BriefRepositoryLive

final class DailyCachePolicyTests: XCTestCase {
  /// The green fixture DTO + its mapped domain. `domain.date` is 2026-06-06 at Europe/Sofia midnight,
  /// so running with `now == domain.date` makes `sofiaToday()` equal the record PK.
  private func greenFixture() throws -> (dto: WireModels.DailyBrief, domain: DomainModels.DailyBrief) {
    try SampleData.dailyBrief(.dailyBriefGreen)
  }

  /// Run `op` with Europe/Sofia + a fixed `now`, the stub API client, and a migrated in-memory DB.
  private func run<T>(
    now: Date,
    stub: StubAPIClient,
    database: DatabaseClient,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(now)
      $0.apiClient = stub.makeClient()
      $0.database = database
    } operation: {
      try await work()
    }
  }

  /// Build an envelope `APIError` with an empty message — shortens the mapping cases.
  private func env(_ code: WireEnum<ErrorCode>, _ status: Int) -> APIError {
    .envelope(code: code, message: "", detail: nil, status: status)
  }

  private func expectBriefError(
    _ expected: BriefError,
    _ work: () async throws -> some Any,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    do {
      _ = try await work()
      XCTFail("expected BriefError.\(expected)", file: file, line: line)
    } catch let error as BriefError {
      XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
      XCTFail("expected BriefError, got \(error)", file: file, line: line)
    }
  }

  func test_dailyBrief_cacheHit_noNetwork() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedDaily(db, domain)
    let stub = StubAPIClient()

    let result = try await run(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    XCTAssertEqual(result, domain)
    XCTAssertEqual(stub.dailyCallCount, 0, "a same-day cache hit must not hit the network")
  }

  func test_dailyBrief_missNoSync_throwsSyncRequired() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory() // empty, no watermark
    let stub = StubAPIClient()

    await expectBriefError(.syncRequired) {
      try await self.run(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
    XCTAssertEqual(stub.dailyCallCount, 0, "an un-synced miss must not hit the network")
  }

  func test_dailyBrief_missSynced_generatesAndPersists() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .success(dto))

    let result = try await run(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    XCTAssertEqual(result, domain)
    XCTAssertEqual(stub.dailyCallCount, 1)
    XCTAssertEqual(stub.lastDailyRefresh, false)
    let count = try await TestDatabase.dailyCount(db)
    XCTAssertEqual(count, 1, "the generated brief must be persisted")
  }

  func test_dailyBrief_generateThenReread_isCacheHit() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .success(dto))

    let first = try await run(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }
    let second = try await run(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    XCTAssertEqual(first, domain)
    XCTAssertEqual(second, domain)
    XCTAssertEqual(stub.dailyCallCount, 1, "the second same-day call must be a cache hit (key↔PK agree)")
  }

  func test_dailyBrief_refresh_overwrites() async throws {
    let (dto, domain) = try greenFixture()
    var newDTO = dto
    newDTO.data.skipOk.toggle() // a distinguishable fresh result, same date PK
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedDaily(db, domain) // the stale cached record
    let stub = StubAPIClient(dailyResult: .success(newDTO))

    let result = try await run(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(true)
    }

    XCTAssertEqual(result.skipOk, !domain.skipOk, "refresh returns the fresh (overwritten) value")
    XCTAssertEqual(result.date, domain.date)
    XCTAssertEqual(stub.dailyCallCount, 1)
    XCTAssertEqual(stub.lastDailyRefresh, true)
    let stored = try await db.read { dbx in try DailyBriefRecord.fetchOne(dbx, key: domain.date) }
    XCTAssertEqual(try stored?.toDomain().skipOk, !domain.skipOk, "the same-day record is overwritten")
    let count = try await TestDatabase.dailyCount(db)
    XCTAssertEqual(count, 1)
  }

  func test_apiError_mapsToBriefError() async throws {
    let cases: [(APIError, BriefError)] = [
      (env(WireEnum(.briefGenerationFailed), 502), .transientGenerationFailed),
      (env(WireEnum(.upstreamTimeout), 504), .transientGenerationFailed),
      (env(WireEnum(.validationError), 422), .validation),
      (env(WireEnum(.unauthorized), 401), .unauthorized),
      (env(WireEnum(.notFound), 404), .serverError),
      (env(WireEnum(rawValue: "some_new_code"), 500), .serverError),
      (.unauthorized, .unauthorized),
    ]

    for (apiError, expected) in cases {
      let (_, domain) = try greenFixture()
      let db = try TestDatabase.makeInMemory()
      try await TestDatabase.seedWatermark(db)
      let stub = StubAPIClient(dailyResult: .failure(apiError))
      await expectBriefError(expected) {
        try await self.run(now: domain.date, stub: stub, database: db) {
          try await BriefRepository.live.dailyBrief(false)
        }
      }
    }
  }

  func test_apiError_500_firstEver_insufficientData() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .failure(env(WireEnum(.internalError), 500)))

    await expectBriefError(.insufficientData) {
      try await self.run(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
  }

  func test_apiError_500_hasPrior_serverError() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    // A prior brief on a DIFFERENT day → hasPriorBrief, but today is still a miss.
    var yesterday = domain
    yesterday.date = domain.date.addingTimeInterval(-86400)
    try await TestDatabase.seedDaily(db, yesterday)
    let stub = StubAPIClient(dailyResult: .failure(env(WireEnum(.internalError), 500)))

    await expectBriefError(.serverError) {
      try await self.run(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
  }

  func test_dailyBrief_transportFailure_throwsTransient() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .failure(.transport("offline")))

    await expectBriefError(.transientGenerationFailed) {
      try await self.run(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
  }

  func test_dailyBrief_mappingError_throwsMappingFailed() async throws {
    let (dto, domain) = try greenFixture()
    var badDTO = dto
    badDTO.data.session.card = WireEnum(rawValue: "bogus_card") // unknown required singular enum
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .success(badDTO))

    await expectBriefError(.mappingFailed) {
      try await self.run(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
  }

  func test_dailyBrief_sofiaDayBoundary_isMiss() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedDaily(db, domain) // record under day D
    let stub = StubAPIClient(dailyResult: .success(dto))

    // Resolve on the next Sofia day → the day-D record must NOT be a stale hit.
    let nextDay = domain.date.addingTimeInterval(86400)
    _ = try await run(now: nextDay, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    XCTAssertEqual(stub.dailyCallCount, 1, "a different Sofia day is a miss → generate, not a stale hit")
  }
}
