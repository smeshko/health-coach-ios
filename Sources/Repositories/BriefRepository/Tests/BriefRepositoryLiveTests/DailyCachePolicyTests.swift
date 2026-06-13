import APIClient
import BriefRepository
import CoachCore
import CoachTestSupport
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
    let stub = BriefAPIStub()

    let result = try await runWithSofia(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(result == domain)
    #expect(stub.dailyCallCount == 0, "a same-day cache hit must not hit the network")
  }

  /// Audit gap #10: a `refresh == true` on a seeded same-day cache with NO watermark. `refresh` skips
  /// the cache-read and hits the sync gate, so a stale-but-cached, un-synced state throws
  /// `.syncRequired` — the cached copy does NOT serve under a gated refresh (both prior refresh-unsynced
  /// tests used an empty DB, leaving this unpinned).
  @Test func test_dailyBrief_refreshTrue_cachedButUnsynced_throwsSyncRequired() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedDaily(db, domain) // same-day cached row, but NO watermark
    let stub = BriefAPIStub()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(true)
      }
    }
    #expect(stub.dailyCallCount == 0, "a gated refresh must not hit the network even with a cached row")
  }

  /// On an un-synced empty DB the gate trips regardless of `refresh` — the refresh true/false paths
  /// converge before the gate, so this parameterized test subsumes the former
  /// test_dailyBrief_refreshUnsynced_throwsSyncRequired (audit MERGE).
  @Test(arguments: [false, true])
  func test_dailyBrief_missNoSync_throwsSyncRequired(refresh: Bool) async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory() // empty, no watermark
    let stub = BriefAPIStub()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(refresh)
      }
    }
    #expect(stub.dailyCallCount == 0, "an un-synced miss/refresh must not hit the network")
  }

  @Test func test_dailyBrief_missSynced_generatesAndPersists() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = BriefAPIStub(dailyResult: .success(dto))

    let result = try await runWithSofia(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(result == domain)
    #expect(stub.dailyCallCount == 1)
    #expect(stub.lastDailyRefresh == false)
    let count = try await TestDatabase.dailyCount(db)
    #expect(count == 1, "the generated brief must be persisted")

    // Folded from test_dailyBrief_generateThenReread_isCacheHit (audit MERGE): a second same-day read
    // is a cache hit (key↔PK agree) — no extra network call.
    let second = try await runWithSofia(now: domain.date, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }
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
    let stub = BriefAPIStub(dailyResult: .success(newDTO))

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
      // Folded from test_dailyBrief_transportFailure_throwsTransient (audit MERGE): a transport error
      // is retry-friendly.
      (.transport("offline"), .transientGenerationFailed),
      // An unknown error code fails envelope decode → `.unexpectedStatus` → retry-friendly (D3).
      (.unexpectedStatus(500), .transientGenerationFailed),
      // A 2xx body whose closed enum is out-of-set (Phase 11.3 strict decode) throws `.decoding`,
      // which maps to the retry-friendly state (DECISIONS #5 — the pre-existing decode-failure
      // policy). On a self-owned API a new closed case is a same-sitting client+server edit (D2), so
      // this is the accepted classification, not a contract-negotiation failure.
      (.decoding("DailyBrief.session.card: out-of-set"), .transientGenerationFailed),
    ]

    for (apiError, expected) in cases {
      let (_, domain) = try greenFixture()
      let db = try TestDatabase.makeInMemory()
      try await TestDatabase.seedWatermark(db)
      let stub = BriefAPIStub(dailyResult: .failure(apiError))
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
    let stub = BriefAPIStub(dailyResult: .failure(envelopeError(.internalError, 500)))

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
    let stub = BriefAPIStub(dailyResult: .failure(envelopeError(.internalError, 500)))

    await expectBriefError(.serverError) {
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
    let stub = BriefAPIStub(dailyResult: .success(dto))

    // Resolve on the next Sofia day → the day-D record must NOT be a stale hit.
    let nextDay = domain.date.addingTimeInterval(86400)
    _ = try await runWithSofia(now: nextDay, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(stub.dailyCallCount == 1, "a different Sofia day is a miss → generate, not a stale hit")
  }

  /// A Europe/Sofia wall-clock midnight, host-independent (used to seed the DST-boundary record).
  private static func sofiaMidnight(year: Int, month: Int, day: Int) -> Date {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return cal.date(from: DateComponents(year: year, month: month, day: day))!
  }

  /// Audit gap #4: daily rollover pinned across a Sofia DST-transition midnight (2026-03-29, EET→EEST,
  /// a 23-hour day) — the riskiest expiry boundary. A brief cached under 2026-03-28 must be a MISS when
  /// resolved on 2026-03-29, not a stale hit (the existing rollover tests use flat +86400 offsets, which
  /// silently skip the short DST day). The seeded record's PK is its own Sofia midnight.
  @Test func test_dailyBrief_dstTransitionRollover_isMiss() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    var dayBefore = domain
    dayBefore.date = Self.sofiaMidnight(year: 2026, month: 3, day: 28) // day before the spring-forward
    try await TestDatabase.seedDaily(db, dayBefore)
    let stub = BriefAPIStub(dailyResult: .success(dto))

    // Resolve at noon on the 23-hour DST day → a different Sofia day → a miss, not a stale hit.
    let dstDayNoon = Self.sofiaMidnight(year: 2026, month: 3, day: 29).addingTimeInterval(12 * 3600)
    _ = try await runWithSofia(now: dstDayNoon, stub: stub, database: db) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(stub.dailyCallCount == 1, "a brief cached the day before a DST transition is not a stale hit")
  }
}
