import Foundation
import GRDB
@testable import PersistenceModels
import XCTest

final class RecordConformanceTests: XCTestCase {
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

  func test_dailyBriefRecord_rowRoundTrips() throws {
    let record = DailyBriefRecord(
      date: day, cached: true, generatedAt: day, constitutionVersion: "v3", body: Data("brief".utf8)
    )
    XCTAssertEqual(try roundTripThroughRow(record), record)
    XCTAssertEqual(DailyBriefRecord.databaseTableName, "dailyBrief")
  }

  func test_weeklyPlanRecord_rowRoundTrips() throws {
    let record = WeeklyPlanRecord(
      isoWeek: "2026-W24", weekStart: day, constantsRecomputed: false, generatedAt: day,
      cached: false, body: Data("plan".utf8)
    )
    XCTAssertEqual(try roundTripThroughRow(record), record)
  }

  func test_profileRecord_rowRoundTrips() throws {
    let record = ProfileRecord(constitutionVersion: "v3", body: Data("profile".utf8))
    XCTAssertEqual(try roundTripThroughRow(record), record)
  }

  func test_checkInRecord_rowRoundTrips() throws {
    let record = CheckInRecord(date: day, giSymptoms: false, kneePain: 2, illness: false)
    XCTAssertEqual(try roundTripThroughRow(record), record)
  }

  func test_strengthTestRecord_rowRoundTrips() throws {
    let record = StrengthTestRecord(date: day, maxPushups: 42, maxPullups: 14)
    XCTAssertEqual(try roundTripThroughRow(record), record)
  }

  func test_syncWatermarkRecord_rowRoundTrips() throws {
    let record = SyncWatermarkRecord(anchor: "anchor-token", serverTime: day)
    XCTAssertEqual(try roundTripThroughRow(record), record)
  }

  func test_records_insertAndFetchViaInMemoryDatabase() throws {
    // End-to-end against an in-memory DB to prove the records persist and fetch (schema is created
    // ad-hoc here; real migrations live in DatabaseLive / Epic 04).
    let queue = try DatabaseQueue()
    try queue.write { db in
      try db.create(table: CheckInRecord.databaseTableName) { table in
        table.column("date", .datetime).primaryKey()
        table.column("giSymptoms", .boolean).notNull()
        table.column("kneePain", .integer).notNull()
        table.column("illness", .boolean).notNull()
      }
      try CheckInRecord(date: day, giSymptoms: true, kneePain: 5, illness: false).insert(db)
    }
    let fetched = try queue.read { db in try CheckInRecord.fetchOne(db) }
    XCTAssertEqual(fetched?.kneePain, 5)
    XCTAssertEqual(fetched?.giSymptoms, true)
  }
}
