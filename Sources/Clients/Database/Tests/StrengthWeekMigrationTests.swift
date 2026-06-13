import CoachCore
import Foundation
import GRDB
import PersistenceModels
import Testing

@testable import Database

struct StrengthWeekMigrationTests {
  @Test func test_migration_addsStrengthWeekColumn_idempotent_preservesAnchor() throws {
    let queue = try DatabaseQueue()

    // Migrate only up to the v1 (3.2-shaped) schema, then seed a watermark row.
    try DatabaseClient.migrator.migrate(queue, upTo: "v1_createCachedEntities")
    try queue.write { db in
      // Insert via raw SQL against the v1 columns (no marker column yet).
      try db.execute(
        sql: "INSERT INTO syncWatermark (id, anchor, serverTime) VALUES (?, ?, ?)",
        arguments: [1, "anchor-token", Date(timeIntervalSince1970: 500)]
      )
    }

    // Run the full migrator (adds the v2 marker column).
    try DatabaseClient.migrator.migrate(queue)
    let columns = try queue.read { db in try db.columns(in: "syncWatermark").map(\.name) }
    #expect(columns.contains("lastStrengthTestSyncedWeek"), "the additive column must exist")
    let firstApplied = try queue.read { db in try DatabaseClient.migrator.appliedMigrations(db) }

    // The pre-existing row's anchor/serverTime survive; the marker defaults nil.
    let preserved = try queue.read { db in try SyncWatermarkRecord.fetchOne(db, key: 1) }
    #expect(preserved?.anchor == "anchor-token")
    #expect(preserved?.lastStrengthTestSyncedWeek == nil)

    // Re-running the migrator is a no-op (no throw) and applies no new migrations — folds the former
    // MigrationTests.test_migratorIsIdempotent (audit MERGE; the appliedMigrations equality lives here).
    #expect(throws: Never.self) { try DatabaseClient.migrator.migrate(queue) }
    let secondApplied = try queue.read { db in try DatabaseClient.migrator.appliedMigrations(db) }
    #expect(firstApplied == secondApplied)
  }

  @Test func test_marker_roundTripsThroughGRDB() throws {
    let database = try DatabaseClient.makeInMemory()
    let week = ISOWeek(year: 2026, week: 24)
    let record = SyncWatermarkRecord(
      anchor: nil, serverTime: Date(timeIntervalSince1970: 0), lastStrengthTestSyncedWeek: week
    )
    try database.writer().write { db in try record.save(db) }

    let fetched = try database.reader().read { db in try SyncWatermarkRecord.fetchOne(db, key: 1) }
    #expect(fetched?.lastStrengthTestSyncedWeek == week, "GRDB must persist + restore the marker")
  }
}
