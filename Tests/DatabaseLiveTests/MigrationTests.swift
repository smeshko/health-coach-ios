import Database
@testable import DatabaseLive
import GRDB
import PersistenceModels
import XCTest

final class MigrationTests: XCTestCase {
  private let tableNames = [
    DailyBriefRecord.databaseTableName,
    WeeklyPlanRecord.databaseTableName,
    CheckInRecord.databaseTableName,
    StrengthTestRecord.databaseTableName,
    SyncWatermarkRecord.databaseTableName,
    ProfileRecord.databaseTableName,
  ]

  func test_migratorCreatesAllSixTables() throws {
    let queue = try DatabaseQueue()
    try DatabaseClient.migrator.migrate(queue)
    try queue.read { db in
      for table in tableNames {
        XCTAssertTrue(try db.tableExists(table), "missing table: \(table)")
      }
    }
  }

  func test_migratorIsIdempotent() throws {
    let queue = try DatabaseQueue()
    try DatabaseClient.migrator.migrate(queue)
    let firstApplied = try queue.read { db in try DatabaseClient.migrator.appliedMigrations(db) }
    // Second run must not throw / duplicate-table-fail.
    XCTAssertNoThrow(try DatabaseClient.migrator.migrate(queue))
    let secondApplied = try queue.read { db in try DatabaseClient.migrator.appliedMigrations(db) }
    XCTAssertEqual(firstApplied, secondApplied)
  }

  func test_makeInMemory_isAlreadyMigrated() async throws {
    let database = try DatabaseClient.makeInMemory()
    let exists = try await database.read { db in try db.tableExists(CheckInRecord.databaseTableName) }
    XCTAssertTrue(exists)
  }
}
