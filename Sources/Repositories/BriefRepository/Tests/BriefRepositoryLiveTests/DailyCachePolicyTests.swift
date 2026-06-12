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
import Testing
import WireModels

import BriefRepositoryLive

struct DailyCachePolicyTests {
  /// The green fixture DTO + its mapped domain. `domain.date` is 2026-06-06 at Europe/Sofia midnight,
  /// so running with `now == domain.date` makes `sofiaToday()` equal the record PK.
  private func greenFixture() throws -> (dto: WireModels.DailyBrief, domain: DomainModels.DailyBrief) {
    try SampleData.dailyBrief(.dailyBriefGreen)
  }

  @Test func test_dailyBrief_cacheHit_noNetwork() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedDaily(db, domain)
    let stub = StubAPIClient()

    let result = try await runWithSofia(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(result == domain)
    #expect(stub.dailyCallCount == 0, "a same-day cache hit must not hit the network")
  }

  @Test func test_dailyBrief_missNoSync_throwsSyncRequired() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory() // empty, no watermark
    let stub = StubAPIClient()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
    #expect(stub.dailyCallCount == 0, "an un-synced miss must not hit the network")
  }

  @Test func test_dailyBrief_refreshUnsynced_throwsSyncRequired() async throws {
    // A refresh on an un-synced state is still gated (locked: PLAN line 66 / Decisions).
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory() // no watermark
    let stub = StubAPIClient()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(true)
      }
    }
    #expect(stub.dailyCallCount == 0, "an un-synced refresh must not hit the network")
  }

  @Test func test_dailyBrief_missSynced_generatesAndPersists() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .success(dto))

    let result = try await runWithSofia(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(result == domain)
    #expect(stub.dailyCallCount == 1)
    #expect(stub.lastDailyRefresh == false)
    let count = try await TestDatabase.dailyCount(db)
    #expect(count == 1, "the generated brief must be persisted")
  }

  @Test func test_dailyBrief_generateThenReread_isCacheHit() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .success(dto))

    let first = try await runWithSofia(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }
    let second = try await runWithSofia(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(first == domain)
    #expect(second == domain)
    #expect(stub.dailyCallCount == 1, "the second same-day call must be a cache hit (key↔PK agree)")
  }

  @Test func test_dailyBrief_refresh_overwrites() async throws {
    let (dto, domain) = try greenFixture()
    var newDTO = dto
    newDTO.data.skipOk.toggle() // a distinguishable fresh result, same date PK
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedDaily(db, domain) // the stale cached record
    let stub = StubAPIClient(dailyResult: .success(newDTO))

    let result = try await runWithSofia(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(true)
    }

    #expect(result.skipOk == !domain.skipOk, "refresh returns the fresh (overwritten) value")
    #expect(result.date == domain.date)
    #expect(stub.dailyCallCount == 1)
    #expect(stub.lastDailyRefresh == true)
    let stored = try await db.read { dbx in try DailyBriefRecord.fetchOne(dbx, key: domain.date) }
    try #expect(stored?.toDomain().skipOk == !domain.skipOk, "the same-day record is overwritten")
    let count = try await TestDatabase.dailyCount(db)
    #expect(count == 1)
  }

  @Test func test_apiError_mapsToBriefError() async throws {
    let cases: [(APIError, BriefError)] = [
      (envelopeError(.briefGenerationFailed, 502), .transientGenerationFailed),
      (envelopeError(.upstreamTimeout, 504), .transientGenerationFailed),
      (envelopeError(.validationError, 422), .validation),
      (envelopeError(.unauthorized, 401), .unauthorized),
      (envelopeError(.notFound, 404), .serverError),
      (.unauthorized, .unauthorized),
    ]

    for (apiError, expected) in cases {
      let (_, domain) = try greenFixture()
      let db = try TestDatabase.makeInMemory()
      try await TestDatabase.seedWatermark(db)
      let stub = StubAPIClient(dailyResult: .failure(apiError))
      await expectBriefError(expected) {
        try await runWithSofia(now: domain.date, stub: stub, database: db) {
          try await BriefRepository.live.dailyBrief(false)
        }
      }
    }
  }

  @Test func test_apiError_500_firstEver_insufficientData() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .failure(envelopeError(.internalError, 500)))

    await expectBriefError(.insufficientData) {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
  }

  @Test func test_apiError_500_hasPrior_serverError() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    // A prior brief on a DIFFERENT day → hasPriorBrief, but today is still a miss.
    var yesterday = domain
    yesterday.date = domain.date.addingTimeInterval(-86400)
    try await TestDatabase.seedDaily(db, yesterday)
    let stub = StubAPIClient(dailyResult: .failure(envelopeError(.internalError, 500)))

    await expectBriefError(.serverError) {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
  }

  @Test func test_dailyBrief_transportFailure_throwsTransient() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(dailyResult: .failure(.transport("offline")))

    await expectBriefError(.transientGenerationFailed) {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
  }

  // NOTE: the former `test_dailyBrief_mappingError_throwsMappingFailed` is removed — an out-of-set
  // required closed enum is no longer constructible in a typed DTO (the closed enums are shared
  // wire↔domain and decode strictly, Phase 11.3), so a `.success(badDTO)` with a bogus card cannot
  // exist. Strict decode is covered by the WireModels decode tests.

  @Test func test_dailyBrief_sofiaDayBoundary_isMiss() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedDaily(db, domain) // record under day D
    let stub = StubAPIClient(dailyResult: .success(dto))

    // Resolve on the next Sofia day → the day-D record must NOT be a stale hit.
    let nextDay = domain.date.addingTimeInterval(86400)
    _ = try await runWithSofia(now: nextDay, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(stub.dailyCallCount == 1, "a different Sofia day is a miss → generate, not a stale hit")
  }
}
