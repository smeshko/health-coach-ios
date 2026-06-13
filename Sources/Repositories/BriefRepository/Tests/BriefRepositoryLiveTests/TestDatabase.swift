import CoachTestSupport
import Database
import DomainModels
import Foundation
import GRDB
import PersistenceModels

/// Brief-record seed helpers for the cache-policy tests, layered onto the shared
/// `CoachTestSupport.TestDatabase` (which provides the migrated in-memory `makeInMemory()`). The
/// seeds live here because they need this repo's `PersistenceModels` record types.
extension TestDatabase {
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
