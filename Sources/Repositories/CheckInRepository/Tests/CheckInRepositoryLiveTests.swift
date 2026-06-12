import CheckInRepository
import CoachCore
import Database
import DatabaseLive
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import Testing

@testable import CheckInRepositoryLive

struct CheckInRepositoryLiveTests {
  /// A fixed Europe/Sofia instant (~09:00 on 2026-06-06). `static` so the `@Sendable` work closures
  /// capture it without capturing the (non-Sendable) test case.
  private static let now = Date(timeIntervalSince1970: 1_780_725_600)

  private func run<T>(
    database: DatabaseClient,
    now: Date = CheckInRepositoryLiveTests.now,
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
  }

  @Test func test_current_returnsTodaysValue() async throws {
    let db = try DatabaseClient.makeInMemory()
    let checkIn = DomainModels.CheckIn(date: Self.now, giSymptoms: true, kneePain: 3, illness: false)
    try await run(database: db) { try await CheckInRepository.live.save(checkIn) }

    let current = try await run(database: db) { try await CheckInRepository.live.current(Self.now) }
    #expect(current?.giSymptoms == true)
    #expect(current?.kneePain == 3)
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
}
