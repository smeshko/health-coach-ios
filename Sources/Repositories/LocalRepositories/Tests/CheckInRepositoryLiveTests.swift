import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import Testing

@testable import LocalRepositories

struct CheckInRepositoryTests {
  /// A fixed Europe/Sofia instant (~09:00 on 2026-06-06). `static` so the `@Sendable` work closures
  /// capture it without capturing the (non-Sendable) test case.
  private static let now = Date(timeIntervalSince1970: 1_780_725_600)

  private func run<T>(
    database: DatabaseClient,
    now: Date = CheckInRepositoryTests.now,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(now)
      $0.database = database
    } operation: {
      try await work()
    }
  }

  @Test func test_save_thenEditSameDay_keepsLatest() async throws {
    let db = try DatabaseClient.makeInMemory()
    let first = DomainModels.CheckIn(date: Self.now, giSymptoms: false, kneePain: 2, illness: false)
    let edited = DomainModels.CheckIn(date: Self.now, giSymptoms: true, kneePain: 5, illness: true)

    try await run(database: db) {
      try await CheckInRepository.live.save(first)
      try await CheckInRepository.live.save(edited)
    }

    let current = try await run(database: db) {
      try await CheckInRepository.live.current(Self.now)
    }
    let count = try await db.read { dbx in try CheckInRecord.fetchCount(dbx) }
    #expect(count == 1, "two same-day saves must collide on one row")
    #expect(current?.kneePain == 5)
    #expect(current?.illness == true)
    // Folded from test_current_returnsTodaysValue (audit MERGE — strict subset): `current` round-trips
    // every field of the latest same-day save, incl. `giSymptoms`.
    #expect(current?.giSymptoms == true)
  }

  @Test func test_current_missing_returnsNil() async throws {
    let db = try DatabaseClient.makeInMemory()
    let current = try await run(database: db) { try await CheckInRepository.live.current(Self.now) }
    #expect(current == nil)
  }

  @Test func test_sameDay_differentClockTime_collidesOnOneRow() async throws {
    let db = try DatabaseClient.makeInMemory()
    let morning = DomainModels.CheckIn(date: Self.now, giSymptoms: false, kneePain: 1, illness: false)
    // +6h — still the same Europe/Sofia day.
    let afternoon = DomainModels.CheckIn(
      date: Self.now.addingTimeInterval(6 * 3600), giSymptoms: false, kneePain: 7, illness: false
    )

    try await run(database: db) {
      try await CheckInRepository.live.save(morning)
      try await CheckInRepository.live.save(afternoon)
    }

    let count = try await db.read { dbx in try CheckInRecord.fetchCount(dbx) }
    #expect(count == 1, "Sofia-day normalization must collapse intra-day saves to one row")
    let current = try await run(database: db) { try await CheckInRepository.live.current(Self.now) }
    #expect(current?.kneePain == 7)
  }

  /// A Europe/Sofia wall-clock instant (built via the Sofia calendar so it's independent of the host).
  private static func sofia(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  /// Audit gap #4: a save at 00:30 Sofia (= 21:30 UTC the previous day) keys to the NEW Sofia day, and
  /// a check-in saved "yesterday" is NOT returned by `current(today)` — cross-day isolation (a stale
  /// check-in would otherwise ride to `/sync` as today's). Every other date test uses flat June offsets.
  @Test func test_sofiaClockTime_keysToNewDay_andIsolatesAcrossDays() async throws {
    let db = try DatabaseClient.makeInMemory()
    // 2026-06-10 00:30 Sofia (= 2026-06-09 21:30 UTC) — the riskiest "is this today or yesterday?" edge.
    let earlyToday = Self.sofia(year: 2026, month: 6, day: 10, hour: 0, minute: 30)
    let yesterday = Self.sofia(year: 2026, month: 6, day: 9, hour: 10, minute: 0)

    try await run(database: db, now: yesterday) {
      try await CheckInRepository.live.save(
        DomainModels.CheckIn(date: yesterday, giSymptoms: true, kneePain: 9, illness: true)
      )
    }
    try await run(database: db, now: earlyToday) {
      try await CheckInRepository.live.save(
        DomainModels.CheckIn(date: earlyToday, giSymptoms: false, kneePain: 2, illness: false)
      )
    }

    // Two distinct Sofia days → two rows; current(today) returns today's, NOT yesterday's stale one.
    let count = try await db.read { dbx in try CheckInRecord.fetchCount(dbx) }
    #expect(count == 2, "a 00:30 Sofia save is a new day, not a collision with yesterday")
    let today = try await run(database: db, now: earlyToday) {
      try await CheckInRepository.live.current(earlyToday)
    }
    #expect(today?.kneePain == 2, "current(today) must return today's check-in, not yesterday's")
    #expect(today?.illness == false)
  }
}
