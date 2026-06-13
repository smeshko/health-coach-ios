import Database
import Foundation
import GRDB
import PersistenceModels
import Testing

// Note: the former test_writeThenReadRoundTrips + test_compositeRecord_roundTrips folded away (audit
// MERGE — strict subsets of SchemaRoundTripTests.test_everyRecordType_roundTrips, which round-trips
// every record type incl. the Data-body composites). The upsert/PK-replace semantics below are unique.
struct ReadWriteTests {
  private static let day = Date(timeIntervalSince1970: 1_780_000_000)

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
}
