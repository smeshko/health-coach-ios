import Database
import Foundation
import GRDB
import PersistenceModels
import Testing

@testable import DatabaseLive

/// Phase 11.2 migration `v3_clearDomainBodyCaches`: it must empty exactly the three composite
/// body-blob tables (their blobs were written by the old hand-rolled coders) and leave the flat
/// columnar tables untouched. Crucially the migration deletes rows without decoding any blob, so a
/// pre-v3 database holding old-format bodies opens cleanly.
struct DomainBodyCacheMigrationTests {
  private let day = Date(timeIntervalSince1970: 1_780_000_000)

  @Test func test_v3_clearsCompositeCaches_keepsFlatRows_opensClean() throws {
    let queue = try DatabaseQueue()

    // Migrate to the pre-v3 (v2) schema, then seed old-format junk bodies + flat rows via raw SQL.
    try DatabaseClient.migrator.migrate(queue, upTo: "v2_addLastStrengthTestSyncedWeek")
    try queue.write { db in
      try db.execute(
        sql: "INSERT INTO dailyBrief (date, cached, generatedAt, constitutionVersion, body) VALUES (?, ?, ?, ?, ?)",
        arguments: [day, true, day, "v3", Data("OLD_FORMAT_BLOB".utf8)]
      )
      try db.execute(
        sql: "INSERT INTO weeklyPlan (isoWeek, weekStart, constantsRecomputed, generatedAt, cached, body) VALUES (?, ?, ?, ?, ?, ?)",
        arguments: ["2026-W24", day, false, day, false, Data("OLD_FORMAT_BLOB".utf8)]
      )
      try db.execute(
        sql: "INSERT INTO profile (id, constitutionVersion, body) VALUES (?, ?, ?)",
        arguments: [1, "v3", Data("OLD_FORMAT_BLOB".utf8)]
      )
      try db.execute(
        sql: "INSERT INTO checkIn (date, giSymptoms, kneePain, illness) VALUES (?, ?, ?, ?)",
        arguments: [day, false, 2, false]
      )
      try db.execute(
        sql: "INSERT INTO strengthTest (date, maxPushups, maxPullups) VALUES (?, ?, ?)",
        arguments: [day, 30, 8]
      )
      try db.execute(
        sql: "INSERT INTO syncWatermark (id, anchor, serverTime) VALUES (?, ?, ?)",
        arguments: [1, "anchor-token", day]
      )
    }

    // Run the full migrator → applies v3. Migrations run at open, never decoding a blob.
    #expect(throws: Never.self) { try DatabaseClient.migrator.migrate(queue) }

    let counts = try queue.read { db in
      (
        daily: try DailyBriefRecord.fetchCount(db),
        weekly: try WeeklyPlanRecord.fetchCount(db),
        profile: try ProfileRecord.fetchCount(db),
        checkIn: try CheckInRecord.fetchCount(db),
        strength: try StrengthTestRecord.fetchCount(db),
        watermark: try SyncWatermarkRecord.fetchCount(db)
      )
    }
    // The three composite body-blob tables are emptied.
    #expect(counts.daily == 0)
    #expect(counts.weekly == 0)
    #expect(counts.profile == 0)
    // The flat columnar tables retain their rows (no body coding to break).
    #expect(counts.checkIn == 1)
    #expect(counts.strength == 1)
    #expect(counts.watermark == 1)
  }
}
