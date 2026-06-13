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

    // Additive (Phase 4.3 / TASK-006): the year-qualified ISO-week marker the sync orchestrator uses
    // to attach a strength test only when due. Nullable, stored as JSON; `DatabaseMigrator` records
    // applied identifiers so a re-run is a no-op. Existing anchor/serverTime are untouched.
    migrator.registerMigration("v2_addLastStrengthTestSyncedWeek") { db in
      try db.alter(table: SyncWatermarkRecord.databaseTableName) { table in
        table.add(column: "lastStrengthTestSyncedWeek", .text)
      }
    }

    // Phase 11.2: DomainModels adopt in-module Codable, replacing the hand-written body coding. The
    // enum-bearing daily-brief and weekly-plan bodies changed shape (closed enums encode wire strings
    // not case names; open enums encode a single raw string not a `kind`/`raw` discriminator), so
    // clear those two once — the caches are re-fetchable, not durable data, and GRDB runs migrations
    // at DB open before any read, so nothing ever decodes an old-format blob (DECISIONS D3). The
    // `profile` body is NOT cleared: `Profile` is enum- and Date-free (only Int/Double/String scalars
    // under member-name keys), so the synthesized coding reads the old blob byte-identically — clearing
    // it would needlessly drop a usable cache and break offline profile-serving for one launch (review
    // round-1 #1). The flat records (check-in, strength test, watermarks) store no body blob.
    migrator.registerMigration("v3_clearDomainBodyCaches") { db in
      try db.execute(sql: "DELETE FROM \(DailyBriefRecord.databaseTableName)")
      try db.execute(sql: "DELETE FROM \(WeeklyPlanRecord.databaseTableName)")
    }

    return migrator
  }
}
