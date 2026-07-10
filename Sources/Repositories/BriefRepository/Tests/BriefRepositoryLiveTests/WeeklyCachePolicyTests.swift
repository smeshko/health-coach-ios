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

@testable import BriefRepositoryLive

struct WeeklyCachePolicyTests {
  /// The deload fixture DTO + its mapped domain. `domain.isoWeek == "2026-W24"` and
  /// `domain.weekStart` is that week's Monday (Europe/Sofia), so running with `now == weekStart`
  /// makes `isoWeekKey(ISOWeek.current)` equal the record PK.
  private func deloadFixture() throws -> (dto: WireModels.WeeklyPlan, domain: DomainModels.WeeklyPlan) {
    try SampleData.weeklyPlan(.weeklyPlanDeload)
  }

  @Test func test_isoWeekKey_formatsYYYYWww() {
    #expect(isoWeekKey(ISOWeek(year: 2026, week: 7)) == "2026-W07")
    #expect(isoWeekKey(ISOWeek(year: 2026, week: 24)) == "2026-W24")
  }

  @Test func test_weeklyBrief_cacheHit_noNetwork() async throws {
    let (_, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWeekly(db, domain)
    let stub = BriefAPIStub()

    let result = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    // A same-week local-store hit is stamped `cached == true` (Epic 9.1 amendment) — otherwise the stored
    // server generation-time flag (false) would mislabel a GRDB hit as fresh.
    var cachedDomain = domain
    cachedDomain.cached = true
    #expect(result == cachedDomain)
    #expect(result.cached == true, "a local-store hit is stamped cached == true")
    #expect(stub.weeklyCallCount == 0, "a same-week cache hit must not hit the network")
  }

  /// On an un-synced empty DB the gate trips regardless of `refresh` — subsumes the former
  /// test_weeklyBrief_refreshUnsynced_throwsSyncRequired (audit MERGE).
  @Test(arguments: [false, true])
  func test_weeklyBrief_missNoSync_throwsSyncRequired(refresh: Bool) async throws {
    let (_, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory() // empty, no watermark
    let stub = BriefAPIStub()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
        try await BriefRepository.live.weeklyBrief(nil, refresh)
      }
    }
    #expect(stub.weeklyCallCount == 0, "an un-synced miss/refresh must not hit the network")
  }

  @Test func test_weeklyBrief_specificWeek_passesKeyAndRoundTrips() async throws {
    let (dto, domain) = try deloadFixture()
    let week = ISOWeek(year: 2026, week: 24) // matches the deload fixture's isoWeek "2026-W24"
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = BriefAPIStub(weeklyResult: .success(dto))

    let first = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(week, false)
    }
    let second = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(week, false)
    }

    // `first` is the generate (cached flag verbatim from the DTO); `second` is the local hit, stamped cached.
    var cachedDomain = domain
    cachedDomain.cached = true
    #expect(first == domain)
    #expect(second == cachedDomain)
    #expect(stub.weeklyCallCount == 1, "a specific-week generate then re-read is a cache hit (key↔PK agree)")
    #expect(stub.lastWeeklyArg == .some("2026-W24"), "a specific week passes the formatted key as the API arg")
  }

  @Test func test_weeklyBrief_missSynced_generatesAndPersists() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = BriefAPIStub(weeklyResult: .success(dto))

    let result = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    #expect(result == domain)
    #expect(stub.weeklyCallCount == 1)
    #expect(stub.lastWeeklyArg == .some(nil), "current week passes nil so the server resolves it")
    let count = try await TestDatabase.weeklyCount(db)
    #expect(count == 1)

    // Folded from test_weeklyBrief_generateThenReread_isCacheHit (audit MERGE): a second same-week read
    // is a cache hit (key↔PK agree) — no extra network call.
    let second = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }
    // The second same-week read is a local hit, stamped cached (Epic 9.1 amendment).
    var cachedDomain = domain
    cachedDomain.cached = true
    #expect(second == cachedDomain)
    #expect(stub.weeklyCallCount == 1, "the second same-week call must be a cache hit (key↔PK agree)")
  }

  @Test func test_weeklyBrief_refresh_overwrites() async throws {
    let (dto, domain) = try deloadFixture()
    var newDTO = dto
    newDTO.data.constantsRecomputed.toggle() // distinguishable fresh result, same isoWeek PK
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedWeekly(db, domain)
    let stub = BriefAPIStub(weeklyResult: .success(newDTO))

    let result = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, true)
    }

    #expect(result.constantsRecomputed == !domain.constantsRecomputed)
    #expect(result.isoWeek == domain.isoWeek)
    #expect(stub.weeklyCallCount == 1)
    #expect(stub.lastWeeklyRefresh == true)
    let count = try await TestDatabase.weeklyCount(db)
    #expect(count == 1, "refresh overwrites the same-week record")
  }

  @Test func test_weeklyBrief_newIsoWeek_regenerates() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedWeekly(db, domain) // record under week 24
    let stub = BriefAPIStub(weeklyResult: .success(dto))

    // Resolve a week later (W+1) → the week-24 record must NOT be a stale hit.
    let nextWeek = domain.weekStart.addingTimeInterval(7 * 86400)
    _ = try await runWithSofia(now: nextWeek, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    #expect(stub.weeklyCallCount == 1, "the first open of a new ISO week regenerates")
  }

  /// A Europe/Sofia wall-clock instant, host-independent.
  private static func sofia(year: Int, month: Int, day: Int, hour: Int) -> Date {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  /// Audit gap #4: weekly `isoWeekKey` rollover across the ISO YEAR boundary (Dec 29–Jan 3, where the
  /// ISO year ≠ the calendar year). A plan cached under 2026-W53 must be a MISS when resolved in
  /// 2027-W01 — if `isoWeekKey` confused the ISO year/week here, a stale plan would serve. (2026 is a
  /// 53-week ISO year; 2027-01-04 is the Monday of 2027-W01.)
  @Test func test_weeklyBrief_isoYearBoundaryRollover_isMiss() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    var w53 = domain
    w53.isoWeek = "2026-W53"
    w53.weekStart = Self.sofia(year: 2026, month: 12, day: 28, hour: 0) // Monday of 2026-W53
    try await TestDatabase.seedWeekly(db, w53)
    let stub = BriefAPIStub(weeklyResult: .success(dto))

    // Resolve in the NEXT ISO week (2027-W01) → key "2027-W01" ≠ seeded "2026-W53" → a miss.
    let nextIsoWeek = Self.sofia(year: 2027, month: 1, day: 4, hour: 9) // Monday of 2027-W01
    _ = try await runWithSofia(now: nextIsoWeek, stub: stub, database: db) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    #expect(stub.weeklyCallCount == 1, "a plan cached under 2026-W53 is not a stale hit in 2027-W01")
  }

  // NOTE: the former `test_weeklyBrief_outOfSetCoreSession_isDropped` is removed — an out-of-set
  // closed-enum card is no longer constructible in a typed DTO (the closed enums are shared
  // wire↔domain and decode strictly, Phase 11.3), so the collection-element drop path can never be
  // reached. Strict decode is covered by the WireModels decode tests.

  // MARK: - Phase 19.2 TASK-001: a corrupt cached row degrades to a miss

  /// Seed a row under `isoWeek` whose `body` is garbage bytes — the memberwise `WeeklyPlanRecord`
  /// init bypasses the domain encoder, so `toDomain()` throws a `DecodingError` on read.
  private static func seedCorruptWeekly(
    _ database: DatabaseClient, isoWeek: String, weekStart: Date
  ) async throws {
    try await database.write { db in
      try WeeklyPlanRecord(
        isoWeek: isoWeek,
        weekStart: weekStart,
        constantsRecomputed: false,
        generatedAt: weekStart,
        cached: false,
        body: Data("not-a-serialized-weekly-plan".utf8)
      ).save(db)
    }
  }

  /// (a) A corrupt current-week row + synced watermark: the decode failure is a MISS — the policy
  /// regenerates and overwrites under the same `isoWeek` key; the second call is a plain cache hit
  /// (stamped `cached == true`). Exactly one degradation notice lands on `.http`.
  @Test func test_weeklyBrief_corruptRowSynced_regeneratesAndOverwrites() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await Self.seedCorruptWeekly(db, isoWeek: domain.isoWeek, weekStart: domain.weekStart)
    let stub = BriefAPIStub(weeklyResult: .success(dto))
    let recorder = LogRecorder()

    let (first, second) = try await withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      let first = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
        try await BriefRepository.live.weeklyBrief(nil, false)
      }
      let second = try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
        try await BriefRepository.live.weeklyBrief(nil, false)
      }
      return (first, second)
    }

    var cachedDomain = domain
    cachedDomain.cached = true
    #expect(first == domain, "the corrupt row is a miss → the fresh generated plan is returned")
    #expect(second == cachedDomain, "the overwritten row decodes → a local hit, stamped cached")
    #expect(stub.weeklyCallCount == 1, "the overwritten row serves from cache — no second network call")
    let count = try await TestDatabase.weeklyCount(db)
    #expect(count == 1, "the corrupt row is overwritten under the same isoWeek key")
    let notices = recorder.entries.filter { $0.level == .notice && $0.category == .http }
    #expect(notices.count == 1, "exactly one decode-degradation notice on .http")
  }

  /// (b) A corrupt current-week row with NO watermark: the miss falls through to the sync gate →
  /// `.syncRequired` (recoverable), never a raw `DecodingError`.
  @Test func test_weeklyBrief_corruptRowUnsynced_throwsSyncRequired() async throws {
    let (_, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory() // no watermark
    try await Self.seedCorruptWeekly(db, isoWeek: domain.isoWeek, weekStart: domain.weekStart)
    let stub = BriefAPIStub()

    await expectBriefError(.syncRequired) {
      try await runWithSofia(now: domain.weekStart, stub: stub, database: db) {
        try await BriefRepository.live.weeklyBrief(nil, false)
      }
    }
    #expect(stub.weeklyCallCount == 0, "the gated miss must not hit the network")
  }
}
