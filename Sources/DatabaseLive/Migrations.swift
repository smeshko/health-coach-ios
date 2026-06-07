import Database
import Foundation
import GRDB
import PersistenceModels

extension DatabaseClient {
  /// The schema migrator for the six cached entities (Decision #1 — definitions live here, since
  /// Phase 2.3 shipped record *types* only). `DatabaseMigrator` records applied identifiers, so
  /// re-running it is an inherent no-op. Never edit a shipped migration; append `vN` migrations.
  static var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()

    migrator.registerMigration("v1_createCachedEntities") { db in
      try db.create(table: DailyBriefRecord.databaseTableName) { table in
        table.column("date", .datetime).primaryKey()
        table.column("cached", .boolean).notNull()
        table.column("generatedAt", .datetime).notNull()
        table.column("constitutionVersion", .text)
        table.column("body", .blob).notNull()
      }

      try db.create(table: WeeklyPlanRecord.databaseTableName) { table in
        table.column("isoWeek", .text).primaryKey()
        table.column("weekStart", .datetime).notNull()
        table.column("constantsRecomputed", .boolean).notNull()
        table.column("generatedAt", .datetime).notNull()
        table.column("cached", .boolean).notNull()
        table.column("body", .blob).notNull()
      }

      try db.create(table: CheckInRecord.databaseTableName) { table in
        table.column("date", .datetime).primaryKey()
        table.column("giSymptoms", .boolean).notNull()
        table.column("kneePain", .integer).notNull()
        table.column("illness", .boolean).notNull()
      }

      try db.create(table: StrengthTestRecord.databaseTableName) { table in
        table.column("date", .datetime).primaryKey()
        table.column("maxPushups", .integer).notNull()
        table.column("maxPullups", .integer).notNull()
      }

      try db.create(table: SyncWatermarkRecord.databaseTableName) { table in
        table.column("id", .integer).primaryKey()
        table.column("anchor", .text)
        table.column("serverTime", .datetime).notNull()
      }

      try db.create(table: ProfileRecord.databaseTableName) { table in
        table.column("id", .integer).primaryKey()
        table.column("constitutionVersion", .text).notNull()
        table.column("body", .blob).notNull()
      }
    }

    return migrator
  }
}
