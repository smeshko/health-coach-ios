import Database
import DatabaseLive
import Foundation
import GRDB
import PersistenceModels
import Testing

struct ReadWriteTests {
  private static let day = Date(timeIntervalSince1970: 1_780_000_000)

  @Test func test_writeThenReadRoundTrips() async throws {
    let day = Self.day
    let database = try DatabaseClient.makeInMemory()
    let record = CheckInRecord(date: day, giSymptoms: true, kneePain: 3, illness: false)

    try await database.write { db in try record.save(db) }
    let fetched = try await database.read { db in try CheckInRecord.fetchAll(db) }

    #expect(fetched == [record])
  }

  @Test func test_upsertKeepsLatest() async throws {
    let day = Self.day
    let database = try DatabaseClient.makeInMemory()

    // Same primary key (`date`) written twice — the second must replace the first.
    try await database.write { db in
      try CheckInRecord(date: day, giSymptoms: false, kneePain: 1, illness: false).save(db)
    }
    try await database.write { db in
      try CheckInRecord(date: day, giSymptoms: true, kneePain: 8, illness: true).save(db)
    }

    let all = try await database.read { db in try CheckInRecord.fetchAll(db) }
    #expect(all.count == 1, "upsert must leave a single row")
    #expect(all.first?.kneePain == 8)
    #expect(all.first?.illness == true)
  }

  @Test func test_compositeRecord_roundTrips() async throws {
    // A composite record with a Data body round-trips through the generic primitives too.
    let day = Self.day
    let database = try DatabaseClient.makeInMemory()
    let record = DailyBriefRecord(
      date: day, cached: true, generatedAt: day, constitutionVersion: "v3", body: Data("brief".utf8)
    )
    try await database.write { db in try record.save(db) }
    let fetched = try await database.read { db in try DailyBriefRecord.fetchAll(db) }
    #expect(fetched == [record])
  }
}
