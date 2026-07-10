import Foundation
import GRDB
import PersistenceModels
import SampleData
import Testing

@testable import Database

/// Phase 19.2 migration `v5_addProfileSyncServerTime`: additive nullable column on `profile`. A
/// pre-upgrade row survives untouched (no data loss, body still decodes) and reads a NULL stamp —
/// which the live repository treats as stale exactly once. Idempotency is pinned via the migrator's
/// recorded identifiers, following the `StrengthWeekMigrationTests` pattern.
struct ProfileSyncStampMigrationTests {
  @Test func test_v5_addsSyncServerTimeColumn_preservesProfileRow_idempotent() throws {
    let queue = try DatabaseQueue()

    // Migrate only up to the pre-v5 (v4) schema, then seed a profile row via raw SQL against the
    // v1-shaped `profile` columns (no stamp column yet — GRDB record encoding would name it).
    try DatabaseClient.migrator.migrate(queue, upTo: "v4_createSessionSelection")
    let profileDomain = try SampleData.profile().domain
    let body = try ProfileRecord(domain: profileDomain).body
    try queue.write { db in
      try db.execute(
        sql: "INSERT INTO profile (id, constitutionVersion, body) VALUES (?, ?, ?)",
        arguments: [1, profileDomain.meta.constitutionVersion, body]
      )
    }

    // Run the full migrator (adds the v5 stamp column).
    try DatabaseClient.migrator.migrate(queue)
    let columns = try queue.read { db in try db.columns(in: "profile").map(\.name) }
    #expect(columns.contains("syncServerTime"), "the additive column must exist")
    let firstApplied = try queue.read { db in try DatabaseClient.migrator.appliedMigrations(db) }

    // The pre-existing row survives with a NULL stamp (= stale exactly once) and still decodes.
    let preserved = try queue.read { db in try ProfileRecord.fetchOne(db, key: 1) }
    #expect(preserved?.syncServerTime == nil, "a pre-upgrade row reads a NULL stamp")
    let decoded = try preserved?.toDomain()
    #expect(decoded == profileDomain, "no existing-row data loss — the body still decodes")

    // Re-running the migrator is a no-op (no throw) and applies no new migrations.
    #expect(throws: Never.self) { try DatabaseClient.migrator.migrate(queue) }
    let secondApplied = try queue.read { db in try DatabaseClient.migrator.appliedMigrations(db) }
    #expect(firstApplied == secondApplied)
  }
}
