import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import Testing

@testable import LocalRepositories

struct StrengthTestRepositoryTests {
  /// ~09:00 on 2026-06-08 (Europe/Sofia). `static` so the `@Sendable` work closures don't capture the
  /// test case.
  private static let now = Date(timeIntervalSince1970: 1_780_898_400)

  private func run<T>(
    database: DatabaseClient,
    now: Date = StrengthTestRepositoryTests.now,
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

  @Test func test_save_thenRetestSameDay_keepsLatest() async throws {
    let db = try DatabaseClient.makeInMemory()
    let first = DomainModels.StrengthTest(date: Self.now, maxPushups: 30, maxPullups: 8)
    let retest = DomainModels.StrengthTest(date: Self.now, maxPushups: 35, maxPullups: 10)

    try await run(database: db) {
      try await StrengthTestRepository.live.save(first)
      try await StrengthTestRepository.live.save(retest)
    }

    let current = try await run(database: db) { try await StrengthTestRepository.live.current(Self.now) }
    let count = try await db.read { dbx in try StrengthTestRecord.fetchCount(dbx) }
    #expect(count == 1, "a same-day re-test must collide on one row")
    #expect(current?.maxPushups == 35)
    #expect(current?.maxPullups == 10)
    // (Folded test_current_returnsLatest here — audit MERGE: `current` returning the latest same-day
    // save is the strict subset asserted by the maxPushups/maxPullups checks above.)
  }

  @Test func test_current_findsTestFromEarlierDay() async throws {
    let db = try DatabaseClient.makeInMemory()
    // A test logged 3 days ago; query "today" must still find it (at-or-before-latest contract).
    let threeDaysAgo = Self.now.addingTimeInterval(-3 * 86400)
    let earlier = DomainModels.StrengthTest(date: threeDaysAgo, maxPushups: 20, maxPullups: 5)
    try await run(database: db) { try await StrengthTestRepository.live.save(earlier) }

    let found = try await run(database: db) { try await StrengthTestRepository.live.current(Self.now) }
    #expect(found?.maxPushups == 20, "a test logged earlier in the week is still found")

    // A newer test (yesterday) then becomes the latest at-or-before today.
    let yesterday = Self.now.addingTimeInterval(-86400)
    let newer = DomainModels.StrengthTest(date: yesterday, maxPushups: 28, maxPullups: 7)
    try await run(database: db) { try await StrengthTestRepository.live.save(newer) }

    let latest = try await run(database: db) { try await StrengthTestRepository.live.current(Self.now) }
    #expect(latest?.maxPushups == 28, "the most recent at-or-before test wins")
  }

  @Test func test_current_excludesFutureTest() async throws {
    let db = try DatabaseClient.makeInMemory()
    // A test dated tomorrow must NOT be returned for a query on today.
    let tomorrow = Self.now.addingTimeInterval(86400)
    let future = DomainModels.StrengthTest(date: tomorrow, maxPushups: 40, maxPullups: 12)
    try await run(database: db) { try await StrengthTestRepository.live.save(future) }

    let found = try await run(database: db) { try await StrengthTestRepository.live.current(Self.now) }
    #expect(found == nil, "a future-dated test is not at-or-before today")
  }

  @Test func test_current_missing_returnsNil() async throws {
    let db = try DatabaseClient.makeInMemory()
    let current = try await run(database: db) { try await StrengthTestRepository.live.current(Self.now) }
    #expect(current == nil)
  }

  /// A Europe/Sofia wall-clock instant, host-independent.
  private static func sofia(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  /// Audit gap #4: same-day saves hours apart collapse to one row (mirrors the CheckIn clock-time test,
  /// missing on the strength side); and with BOTH a past and a future row stored, `current(today)`
  /// returns the PAST one — if the `date <= day` filter regressed, `ORDER BY date DESC` alone would
  /// wrongly pick the future row.
  @Test func test_sofiaClockTime_collapsesSameDay_andExcludesFutureRow() async throws {
    let db = try DatabaseClient.makeInMemory()
    let morning = Self.sofia(year: 2026, month: 6, day: 8, hour: 8, minute: 0)
    let evening = Self.sofia(year: 2026, month: 6, day: 8, hour: 20, minute: 0) // same Sofia day
    let future = Self.sofia(year: 2026, month: 6, day: 11, hour: 9, minute: 0) // a later day

    try await run(database: db, now: evening) {
      try await StrengthTestRepository.live.save(
        DomainModels.StrengthTest(date: morning, maxPushups: 20, maxPullups: 5)
      )
      try await StrengthTestRepository.live.save(
        DomainModels.StrengthTest(date: evening, maxPushups: 33, maxPullups: 9)
      )
      try await StrengthTestRepository.live.save(
        DomainModels.StrengthTest(date: future, maxPushups: 50, maxPullups: 15)
      )
    }

    // The two same-day saves collapse to one row; the future row is a second row.
    let count = try await db.read { dbx in try StrengthTestRecord.fetchCount(dbx) }
    #expect(count == 2, "same-Sofia-day saves collide on one row; the future-dated save is separate")

    // Queried on the same day as the collapsed pair, current returns that day's latest — never the
    // future row.
    let current = try await run(database: db, now: evening) {
      try await StrengthTestRepository.live.current(evening)
    }
    #expect(current?.maxPushups == 33, "current returns the at-or-before-today row, not the future one")
  }
}
