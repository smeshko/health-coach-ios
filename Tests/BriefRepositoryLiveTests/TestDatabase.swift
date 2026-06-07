import Database
import DatabaseLive
import DomainModels
import Foundation
import GRDB
import PersistenceModels

/// Migrated in-memory `Database` fixtures + seed helpers for the cache-policy tests. Uses the real
/// `DatabaseLive` migrations so `Record.fetchOne`/`save` run against the actual schema.
enum TestDatabase {
  // `DatabaseClient` (the interface's exported alias) avoids the `Database` module-vs-`GRDB.Database`
  // ambiguity in a file that imports both.
  static func makeInMemory() throws -> DatabaseClient {
    try DatabaseClient.makeInMemory()
  }

  /// Seed a successful sync watermark (so the sync-gate passes).
  static func seedWatermark(_ database: DatabaseClient) async throws {
    try await database.write { db in
      try SyncWatermarkRecord(anchor: nil, serverTime: Date(timeIntervalSince1970: 0)).save(db)
    }
  }

  static func seedDaily(_ database: DatabaseClient, _ domain: DomainModels.DailyBrief) async throws {
    try await database.write { db in try DailyBriefRecord(domain: domain).save(db) }
  }

  static func seedWeekly(_ database: DatabaseClient, _ domain: DomainModels.WeeklyPlan) async throws {
    try await database.write { db in try WeeklyPlanRecord(domain: domain).save(db) }
  }

  static func dailyCount(_ database: DatabaseClient) async throws -> Int {
    try await database.read { db in try DailyBriefRecord.fetchCount(db) }
  }

  static func weeklyCount(_ database: DatabaseClient) async throws -> Int {
    try await database.read { db in try WeeklyPlanRecord.fetchCount(db) }
  }
}
