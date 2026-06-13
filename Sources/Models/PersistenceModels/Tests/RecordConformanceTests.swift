import CoachCore
import Database
import Foundation
import GRDB
import Testing

@testable import PersistenceModels

struct RecordConformanceTests {
  /// Round-trip a record through GRDB's encode (`databaseDictionary`) → `Row` → `init(row:)`,
  /// proving the `FetchableRecord` + `PersistableRecord` + `Codable` conformances and stable columns
  /// without needing a database connection.
  private func roundTripThroughRow<R: FetchableRecord & EncodableRecord & Equatable>(
    _ record: R
  ) throws -> R {
    let row = try Row(record.databaseDictionary.mapValues { $0 as (any DatabaseValueConvertible)? })
    return try R(row: row)
  }

  private let day = Date(timeIntervalSince1970: 1_780_000_000)

  @Test func test_dailyBriefRecord_rowRoundTrips() throws {
    let record = DailyBriefRecord(
      date: day, cached: true, generatedAt: day, constitutionVersion: "v3", body: Data("brief".utf8)
    )
    #expect(try roundTripThroughRow(record) == record)
    #expect(DailyBriefRecord.databaseTableName == "dailyBrief")
  }

  @Test func test_weeklyPlanRecord_rowRoundTrips() throws {
    let record = WeeklyPlanRecord(
      isoWeek: "2026-W24", weekStart: day, constantsRecomputed: false, generatedAt: day,
      cached: false, body: Data("plan".utf8)
    )
    #expect(try roundTripThroughRow(record) == record)
  }

  @Test func test_profileRecord_rowRoundTrips() throws {
    let record = ProfileRecord(constitutionVersion: "v3", body: Data("profile".utf8))
    #expect(try roundTripThroughRow(record) == record)
  }

  @Test func test_strengthTestRecord_rowRoundTrips() throws {
    let record = StrengthTestRecord(date: day, maxPushups: 42, maxPullups: 14)
    #expect(try roundTripThroughRow(record) == record)
  }

  @Test func test_syncWatermarkRecord_rowRoundTrips() throws {
    let record = SyncWatermarkRecord(anchor: "anchor-token", serverTime: day)
    #expect(try roundTripThroughRow(record) == record)
  }

  /// End-to-end against an in-memory DB built by the **production migrator** (`makeInMemory` runs the
  /// real v1–v3 migrations), so an insert/fetch round-trip catches drift between the records and the
  /// shipped schema — which the ad-hoc-schema variant could not. Covers the flat `CheckInRecord`
  /// (subsuming the standalone row round-trip) and the non-nil `lastStrengthTestSyncedWeek` ISOWeek
  /// marker, the only nontrivial GRDB column type, through the real Row/DB path.
  @Test func test_records_insertAndFetchViaMigratedDatabase() throws {
    let database = try DatabaseClient.makeInMemory()

    let checkIn = CheckInRecord(date: day, giSymptoms: true, kneePain: 5, illness: false)
    let week = ISOWeek(year: 2026, week: 24)
    let watermark = SyncWatermarkRecord(anchor: "anchor-token", serverTime: day, lastStrengthTestSyncedWeek: week)
    try database.writer().write { db in
      try checkIn.insert(db)
      try watermark.save(db)
    }

    let fetchedCheckIn = try database.reader().read { db in try CheckInRecord.fetchOne(db) }
    #expect(fetchedCheckIn == checkIn)

    let fetchedWatermark = try database.reader().read { db in try SyncWatermarkRecord.fetchOne(db) }
    #expect(
      fetchedWatermark?.lastStrengthTestSyncedWeek == week,
      "the ISOWeek marker round-trips non-nil through the real schema"
    )
  }
}
