import CoachCore
import Database
import DatabaseLive
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import StrengthTestRepository
import Testing

@testable import StrengthTestRepositoryLive

struct StrengthTestRepositoryLiveTests {
  /// ~09:00 on 2026-06-08 (Europe/Sofia). `static` so the `@Sendable` work closures don't capture the
  /// test case.
  private static let now = Date(timeIntervalSince1970: 1_780_898_400)

  private func run<T>(
    database: DatabaseClient,
    now: Date = StrengthTestRepositoryLiveTests.now,
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
  }

  @Test func test_current_returnsLatest() async throws {
    let db = try DatabaseClient.makeInMemory()
    let test = DomainModels.StrengthTest(date: Self.now, maxPushups: 25, maxPullups: 6)
    try await run(database: db) { try await StrengthTestRepository.live.save(test) }

    let current = try await run(database: db) { try await StrengthTestRepository.live.current(Self.now) }
    #expect(current?.maxPushups == 25)
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

  @Test func test_mock_returnsCannedValue() async throws {
    let logged = try await StrengthTestRepository.mock(scenario: .logged).current(Self.now)
    #expect(logged?.maxPushups == 30)

    let empty = try await StrengthTestRepository.mock(scenario: .empty).current(Self.now)
    #expect(empty == nil)
  }
}
