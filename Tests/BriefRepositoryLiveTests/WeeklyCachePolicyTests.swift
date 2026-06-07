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

@testable import BriefRepositoryLive

final class WeeklyCachePolicyTests: XCTestCase {
  /// The deload fixture DTO + its mapped domain. `domain.isoWeek == "2026-W24"` and
  /// `domain.weekStart` is that week's Monday (Europe/Sofia), so running with `now == weekStart`
  /// makes `isoWeekKey(ISOWeek.current)` equal the record PK.
  private func deloadFixture() throws -> (dto: WireModels.WeeklyPlan, domain: DomainModels.WeeklyPlan) {
    try SampleData.weeklyPlan(.weeklyPlanDeload)
  }

  func test_isoWeekKey_formatsYYYYWww() {
    XCTAssertEqual(isoWeekKey(ISOWeek(year: 2026, week: 7)), "2026-W07")
    XCTAssertEqual(isoWeekKey(ISOWeek(year: 2026, week: 24)), "2026-W24")
  }

  func test_weeklyBrief_cacheHit_noNetwork() async throws {
    let (_, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWeekly(db, domain)
    let stub = StubAPIClient()

    let result = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    XCTAssertEqual(result, domain)
    XCTAssertEqual(stub.weeklyCallCount, 0, "a same-week cache hit must not hit the network")
  }

  func test_weeklyBrief_missNoSync_throwsSyncRequired() async throws {
    let (_, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory() // empty, no watermark
    let stub = StubAPIClient()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
        try await BriefRepository.live.weeklyBrief(nil, false)
      }
    }
    XCTAssertEqual(stub.weeklyCallCount, 0)
  }

  func test_weeklyBrief_refreshUnsynced_throwsSyncRequired() async throws {
    let (_, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory() // no watermark
    let stub = StubAPIClient()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
        try await BriefRepository.live.weeklyBrief(nil, true)
      }
    }
    XCTAssertEqual(stub.weeklyCallCount, 0, "an un-synced refresh must not hit the network")
  }

  func test_weeklyBrief_specificWeek_passesKeyAndRoundTrips() async throws {
    let (dto, domain) = try deloadFixture()
    let week = ISOWeek(year: 2026, week: 24) // matches the deload fixture's isoWeek "2026-W24"
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(weeklyResult: .success(dto))

    let first = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(week, false)
    }
    let second = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(week, false)
    }

    XCTAssertEqual(first, domain)
    XCTAssertEqual(second, domain)
    XCTAssertEqual(stub.weeklyCallCount, 1, "a specific-week generate then re-read is a cache hit (key↔PK agree)")
    XCTAssertEqual(stub.lastWeeklyArg, .some("2026-W24"), "a specific week passes the formatted key as the API arg")
  }

  func test_weeklyBrief_missSynced_generatesAndPersists() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(weeklyResult: .success(dto))

    let result = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    XCTAssertEqual(result, domain)
    XCTAssertEqual(stub.weeklyCallCount, 1)
    XCTAssertEqual(stub.lastWeeklyArg, .some(nil), "current week passes nil so the server resolves it")
    let count = try await TestDatabase.weeklyCount(db)
    XCTAssertEqual(count, 1)
  }

  func test_weeklyBrief_generateThenReread_isCacheHit() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(weeklyResult: .success(dto))

    let first = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }
    let second = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    XCTAssertEqual(first, domain)
    XCTAssertEqual(second, domain)
    XCTAssertEqual(stub.weeklyCallCount, 1, "the second same-week call must be a cache hit (key↔PK agree)")
  }

  func test_weeklyBrief_refresh_overwrites() async throws {
    let (dto, domain) = try deloadFixture()
    var newDTO = dto
    newDTO.data.constantsRecomputed.toggle() // distinguishable fresh result, same isoWeek PK
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedWeekly(db, domain)
    let stub = StubAPIClient(weeklyResult: .success(newDTO))

    let result = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, true)
    }

    XCTAssertEqual(result.constantsRecomputed, !domain.constantsRecomputed)
    XCTAssertEqual(result.isoWeek, domain.isoWeek)
    XCTAssertEqual(stub.weeklyCallCount, 1)
    XCTAssertEqual(stub.lastWeeklyRefresh, true)
    let count = try await TestDatabase.weeklyCount(db)
    XCTAssertEqual(count, 1, "refresh overwrites the same-week record")
  }

  func test_weeklyBrief_newIsoWeek_regenerates() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedWeekly(db, domain) // record under week 24
    let stub = StubAPIClient(weeklyResult: .success(dto))

    // Resolve a week later (W+1) → the week-24 record must NOT be a stale hit.
    let nextWeek = domain.weekStart.addingTimeInterval(7 * 86400)
    _ = try await runWithSofia(now: nextWeek, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    XCTAssertEqual(stub.weeklyCallCount, 1, "the first open of a new ISO week regenerates")
  }

  // NOTE: `domainWeeklyPlan` is a TOTAL mapping — it has no required *singular* closed enum, so unlike
  // the daily path it never throws `MappingError` (core/extras sessions are collection elements that
  // are DROPPED when out-of-set). The `.mappingFailed` wrapper is still present in `weeklyPlanPolicy`
  // (defensive, and proven by the daily mapping-error test); here we document the real behavior: an
  // out-of-set core session is dropped, not surfaced as an error.
  func test_weeklyBrief_outOfSetCoreSession_isDropped() async throws {
    let (dto, domain) = try deloadFixture()
    try XCTSkipIf(dto.data.core.isEmpty, "fixture needs a core session to exercise the drop path")
    var badDTO = dto
    badDTO.data.core[0].card = WireEnum(rawValue: "bogus_card") // out-of-set collection element
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = StubAPIClient(weeklyResult: .success(badDTO))

    let result = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    XCTAssertEqual(result.core.count, domain.core.count - 1, "the out-of-set core session is dropped")
  }
}
