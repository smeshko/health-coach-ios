import GRDB
import PersistenceModels
import Testing

@testable import Database

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

  // Note: test_migratorIsIdempotent folded into StrengthWeekMigrationTests
  // (test_migration_addsStrengthWeekColumn_idempotent_preservesAnchor) — audit MERGE; the
  // appliedMigrations-equality assert lives there now.

  @Test func test_makeInMemory_isAlreadyMigrated() async throws {
    let database = try DatabaseClient.makeInMemory()
    let exists = try await database.read { db in try db.tableExists(CheckInRecord.databaseTableName) }
    #expect(exists)
  }
}
