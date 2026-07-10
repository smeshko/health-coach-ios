import APIClient
import BriefRepository
import CoachCore
import CoachTestSupport
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import LogClient
import PersistenceModels
import SampleData
import Testing
import WireModels

import BriefRepositoryLive

/// Phase 19.2 TASK-001: a corrupt/format-drifted cached `DailyBriefRecord` degrades to a cache MISS
/// instead of bricking the Sofia day behind an unrecoverable Retry — the non-refresh branch falls
/// through to the generate path (whose `save` overwrites the same-day row) and the peek reports "no
/// usable cache" (`nil`). Split out of `DailyCachePolicyTests` for the 250-line type-body cap; the
/// weekly twin lives in `WeeklyCachePolicyTests`.
struct DecodeDegradationTests {
  /// The green fixture DTO + its mapped domain (`domain.date` = 2026-06-06 Europe/Sofia midnight).
  private func greenFixture() throws -> (dto: WireModels.DailyBrief, domain: DomainModels.DailyBrief) {
    try SampleData.dailyBrief(.dailyBriefGreen)
  }

  /// Seed a same-day row whose `body` is garbage bytes — the memberwise `DailyBriefRecord` init
  /// bypasses the domain encoder, so `toDomain()` throws a `DecodingError` on read.
  private static func seedCorruptDaily(_ database: DatabaseClient, date: Date) async throws {
    try await database.write { db in
      try DailyBriefRecord(
        date: date,
        cached: false,
        generatedAt: date,
        constitutionVersion: nil,
        body: Data("not-a-serialized-daily-brief".utf8)
      ).save(db)
    }
  }

  /// (a) A corrupt same-day row + synced watermark: the decode failure is a MISS — the policy calls
  /// the API, persists, and returns the fresh brief; the second call serves the (now valid) cache
  /// with no further network. Exactly one degradation notice lands on `.http`.
  @Test func test_dailyBrief_corruptRowSynced_regeneratesAndOverwrites() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await Self.seedCorruptDaily(db, date: domain.date)
    let stub = BriefAPIStub(dailyResult: .success(dto))
    let recorder = LogRecorder()

    let (first, second) = try await withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      let first = try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
      let second = try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
      return (first, second)
    }

    #expect(first == domain, "the corrupt row is a miss → the fresh generated brief is returned")
    #expect(second == domain, "the overwritten row decodes → a plain cache hit")
    #expect(stub.dailyCallCount == 1, "the overwritten row serves from cache — no second network call")
    let stored = try await db.read { dbx in try DailyBriefRecord.fetchOne(dbx, key: domain.date) }
    try #expect(stored?.toDomain() == domain, "the corrupt row is overwritten under the same date PK")
    let notices = recorder.entries.filter { $0.level == .notice && $0.category == .http }
    #expect(notices.count == 1, "exactly one decode-degradation notice on .http")
  }

  /// (b) A corrupt same-day row with NO watermark: the miss falls through to the sync gate →
  /// `.syncRequired` (recoverable), never a raw `DecodingError`.
  @Test func test_dailyBrief_corruptRowUnsynced_throwsSyncRequired() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory() // no watermark
    try await Self.seedCorruptDaily(db, date: domain.date)
    let stub = BriefAPIStub()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
    #expect(stub.dailyCallCount == 0, "the gated miss must not hit the network")
  }

  /// (c) The peek on a corrupt row reports "no usable cache": `nil`, zero network, one `.http` notice
  /// — it never generates or repairs.
  @Test func test_cachedDailyBrief_corruptRow_returnsNil_noNetwork() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await Self.seedCorruptDaily(db, date: domain.date)
    let stub = BriefAPIStub()
    let recorder = LogRecorder()

    let result = try await withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      try await runWithSofia(now: domain.date, stub: stub, database: db) {
        try await BriefRepository.live.cachedDailyBrief()
      }
    }

    #expect(result == nil, "a corrupt row is 'no usable cache' — the peek returns nil")
    #expect(stub.dailyCallCount == 0, "the peek must never hit the network")
    let notices = recorder.entries.filter { $0.level == .notice && $0.category == .http }
    #expect(notices.count == 1, "exactly one decode-degradation notice on .http")
  }
}
