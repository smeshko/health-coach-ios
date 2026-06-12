import Database
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import SampleData
import Testing

@testable import DatabaseLive

/// Phase 11.2 migration `v3_clearDomainBodyCaches`: it must empty exactly the two enum-bearing
/// composite body-blob tables (daily brief / weekly plan — whose blobs were written by the old
/// hand-rolled coders), leave the format-compatible `profile` body AND the flat columnar tables
/// untouched. Crucially the migration deletes rows without decoding any blob, so a pre-v3 database
/// holding old-format bodies opens cleanly.
struct DomainBodyCacheMigrationTests {
  private let day = Date(timeIntervalSince1970: 1_780_000_000)

  @Test func test_v3_clearsBriefCaches_keepsProfileAndFlatRows_opensClean() throws {
    let queue = try DatabaseQueue()

    // Migrate to the pre-v3 (v2) schema, then seed old-format junk brief bodies + a real (format-stable)
    // profile body + flat rows.
    try DatabaseClient.migrator.migrate(queue, upTo: "v2_addLastStrengthTestSyncedWeek")
    let profileDomain = try SampleData.profile().domain
    try queue.write { db in
      try db.execute(
        sql: "INSERT INTO dailyBrief (date, cached, generatedAt, constitutionVersion, body) VALUES (?, ?, ?, ?, ?)",
        arguments: [day, true, day, "v3", Data("OLD_FORMAT_BLOB".utf8)]
      )
      try db.execute(
        sql: """
        INSERT INTO weeklyPlan (isoWeek, weekStart, constantsRecomputed, generatedAt, cached, body)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        arguments: ["2026-W24", day, false, day, false, Data("OLD_FORMAT_BLOB".utf8)]
      )
      // `Profile` is enum/Date-free, so its body format is unchanged across 11.2 — seed a real one
      // (the new coding equals the old) and assert it survives + decodes after the migration.
      try ProfileRecord(domain: profileDomain).save(db)
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
    // The two enum-bearing composite tables are emptied.
    #expect(counts.daily == 0)
    #expect(counts.weekly == 0)
    // The format-stable profile cache + the flat columnar tables retain their rows.
    #expect(counts.profile == 1)
    #expect(counts.checkIn == 1)
    #expect(counts.strength == 1)
    #expect(counts.watermark == 1)

    // The retained profile body still decodes cleanly (proving format compatibility across 11.2).
    let fetchedProfile = try queue.read { db in try ProfileRecord.fetchOne(db) }
    let decodedProfile = try fetchedProfile?.toDomain()
    #expect(decodedProfile == profileDomain)
  }
}
