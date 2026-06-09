import Database
import GRDB
import PersistenceModels
import Testing

@testable import DatabaseLive

struct MigrationTests {
  private let tableNames = [
    DailyBriefRecord.databaseTableName,
    WeeklyPlanRecord.databaseTableName,
    CheckInRecord.databaseTableName,
    StrengthTestRecord.databaseTableName,
    SyncWatermarkRecord.databaseTableName,
    ProfileRecord.databaseTableName,
  ]

  @Test func test_migratorCreatesAllSixTables() throws {
    let queue = try DatabaseQueue()
    try DatabaseClient.migrator.migrate(queue)
    try queue.read { db in
      for table in tableNames {
        let exists = try db.tableExists(table)
        #expect(exists, "missing table: \(table)")
      }
    }
  }

  @Test func test_migratorIsIdempotent() throws {
    let queue = try DatabaseQueue()
    try DatabaseClient.migrator.migrate(queue)
    let firstApplied = try queue.read { db in try DatabaseClient.migrator.appliedMigrations(db) }
    // Second run must not throw / duplicate-table-fail.
    #expect(throws: Never.self) { try DatabaseClient.migrator.migrate(queue) }
    let secondApplied = try queue.read { db in try DatabaseClient.migrator.appliedMigrations(db) }
    #expect(firstApplied == secondApplied)
  }

  @Test func test_makeInMemory_isAlreadyMigrated() async throws {
    let database = try DatabaseClient.makeInMemory()
    let exists = try await database.read { db in try db.tableExists(CheckInRecord.databaseTableName) }
    #expect(exists)
  }
}
