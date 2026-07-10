import Dependencies
import Foundation
import GRDB
import LogClient
import PersistenceModels
import Testing

@testable import Database

/// Covers `DatabaseClient.makeLive(path:)` — the production `liveValue` entry point that every other test
/// bypasses via `makeInMemory()`. Exercises on-disk open + migrate-from-scratch, row persistence, and a
/// second open over the SAME file (the app-relaunch path: migrations must be idempotent and the data must
/// survive). In-memory hides file-mode open failures and cross-open migration ordering.
struct MakeLiveTests {
  private static let day = Date(timeIntervalSince1970: 1_780_000_000)

  @Test func test_makeLive_opensOnDisk_persistsAcrossReopen_migratesIdempotently() async throws {
    // A unique temp DIRECTORY so parallel runs don't collide and the sqlite file plus its -wal/-shm
    // siblings are all removed together in teardown (no leakage between runs).
    let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("makeLiveTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("coachapp.sqlite").path

    // First open: creates + migrates the on-disk DB from scratch.
    var first: DatabaseClient? = try DatabaseClient.makeLive(path: path)
    #expect(FileManager.default.fileExists(atPath: path), "makeLive creates the on-disk database file")

    let appliedFirst = try await first!.read { db in try DatabaseClient.migrator.appliedMigrations(db) }
    let completedFirst = try await first!.read { db in try DatabaseClient.migrator.hasCompletedMigrations(db) }
    #expect(completedFirst, "a fresh on-disk open runs every registered migration")
    #expect(!appliedFirst.isEmpty)

    // Write a row through the live client, then read it back off disk.
    try await first!.write { db in
      try CheckInRecord(date: Self.day, giSymptoms: true, kneePain: 4, illness: false).save(db)
    }
    let firstRead = try await first!.read { db in try CheckInRecord.fetchAll(db) }
    #expect(firstRead.count == 1, "a row written through makeLive reads back on disk")

    // Release the first connection — simulate the app closing before it relaunches.
    first = nil

    // Second open over the SAME file (a fresh app launch): migrations stay idempotent and the row survives.
    let second = try DatabaseClient.makeLive(path: path)
    let appliedSecond = try await second.read { db in try DatabaseClient.migrator.appliedMigrations(db) }
    let completedSecond = try await second.read { db in try DatabaseClient.migrator.hasCompletedMigrations(db) }
    #expect(completedSecond, "the re-opened DB is still fully migrated")
    #expect(appliedSecond == appliedFirst, "re-opening applies no new migrations (idempotent)")

    let survived = try await second.read { db in try CheckInRecord.fetchAll(db) }
    #expect(survived.count == 1, "the row from the first open survives a re-open")
    #expect(survived.first?.kneePain == 4, "the persisted values are intact across re-open")
  }

  /// CR-2 (release audit 2026-06-18): a corrupt on-disk file must NOT brick the launch. `makeLiveResilient`
  /// quarantines the bad file and recreates a usable DB, so the app opens instead of crash-looping into a
  /// reinstall. Phase 18.4 extends the pin: every sidecar moves aside too (`-journal` is the one a
  /// rollback-journal `DatabaseQueue` actually leaves behind), and the recovery is recorded on the
  /// always-on `.http` category. Mirrors the unique-temp-dir hygiene of the test above.
  @Test func test_makeLiveResilient_recoversFromCorruptFile_quarantinesItAndItsSidecars() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("makeLiveResilientTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("coachapp.sqlite").path

    // Plant a file that is not a valid SQLite database (so the open/migrate path throws with a proven
    // corruption code) plus every sidecar a DatabaseQueue can leave behind: `-journal` (rollback-journal
    // mode — the live mode) and `-wal`/`-shm` (a WAL-mode past life).
    try Data("not a database".utf8).write(to: URL(fileURLWithPath: path))
    for suffix in ["-journal", "-wal", "-shm"] {
      try Data("sidecar".utf8).write(to: URL(fileURLWithPath: path + suffix))
    }

    // Resilient open must still return a usable, fully-migrated client (no throw, no crash).
    let recorder = LogRecorder()
    let recovered = withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      DatabaseClient.makeLiveResilient(path: path)
    }
    let completed = try await recovered.read { db in try DatabaseClient.migrator.hasCompletedMigrations(db) }
    #expect(completed, "the recovered DB is freshly created and fully migrated")
    try await recovered.write { db in
      try CheckInRecord(date: Self.day, giSymptoms: false, kneePain: 2, illness: false).save(db)
    }
    let rows = try await recovered.read { db in try CheckInRecord.fetchAll(db) }
    #expect(rows.count == 1, "the recovered DB accepts reads and writes")

    // The bad file AND its WAL sidecars were moved aside rather than left in place to fail again.
    for suffix in ["", "-wal", "-shm"] {
      #expect(
        FileManager.default.fileExists(atPath: path + suffix + ".corrupt"),
        "the '\(suffix)' file is quarantined to a .corrupt sibling"
      )
    }
    // SQLite itself deletes an INVALID hot journal during the failing open (before quarantine runs),
    // so `-journal.corrupt` may not appear here — what matters is the stale journal cannot poison the
    // next launch. The deterministic four-way move is pinned in the injected-open test below.
    #expect(!FileManager.default.fileExists(atPath: path + "-journal"))
    // Moved, not copied (the fresh rollback-journal DB never recreates -wal/-shm).
    #expect(!FileManager.default.fileExists(atPath: path + "-wal"))
    #expect(!FileManager.default.fileExists(atPath: path + "-shm"))

    // The quarantine + successful recreate is recorded on the ALWAYS-ON `.http` category.
    let entry = try #require(recorder.entries.first)
    #expect(entry.category == .http)
    #expect(entry.message.contains("DB corrupt"))
    #expect(entry.message.contains("quarantined, recreated"))
  }

  /// Phase 18.4: only PROVEN corruption quarantines. The classifier is the single decision point —
  /// pin the whole matrix so a transient/lockable failure can never be reclassified into quarantine
  /// (which for a healthy-but-busy file would be silent total data loss).
  @Test func test_classifyOpenFailure_quarantinesOnlyProvenCorruption() {
    // Proven corruption — primary result codes SQLITE_CORRUPT / SQLITE_NOTADB → quarantine.
    #expect(DatabaseClient.classifyOpenFailure(DatabaseError(resultCode: .SQLITE_CORRUPT)) == .quarantine)
    #expect(DatabaseClient.classifyOpenFailure(DatabaseError(resultCode: .SQLITE_NOTADB)) == .quarantine)
    // An EXTENDED corruption code still classifies by its primary code.
    #expect(DatabaseClient.classifyOpenFailure(DatabaseError(resultCode: .SQLITE_CORRUPT_INDEX)) == .quarantine)

    // Transient / environmental failures PRESERVE the file (in-memory session, relaunch retries).
    let transient: [ResultCode] = [.SQLITE_BUSY, .SQLITE_LOCKED, .SQLITE_IOERR, .SQLITE_FULL, .SQLITE_CANTOPEN]
    for code in transient {
      #expect(
        DatabaseClient.classifyOpenFailure(DatabaseError(resultCode: code)) == .preserve,
        "\(code) must preserve the on-disk file"
      )
    }

    // A non-SQLite error (the throwing-migration-bug stand-in) preserves too — a code bug must
    // never destroy data.
    struct MigrationBug: Error {}
    #expect(DatabaseClient.classifyOpenFailure(MigrationBug()) == .preserve)
  }

  /// Phase 18.4 preserve path: a transient open failure over a HEALTHY database leaves the file
  /// byte-identical (no quarantine, no recreate), returns a working in-memory client for the session,
  /// and records the decision — write-loss explicit — on the always-on `.http` category.
  @Test func test_makeLiveResilient_transientFailure_preservesFileAndFallsBackInMemory() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("makeLiveResilientTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("coachapp.sqlite").path

    // A healthy on-disk database with a row in it.
    var seed: DatabaseClient? = try DatabaseClient.makeLive(path: path)
    try await seed!.write { db in
      try CheckInRecord(date: Self.day, giSymptoms: false, kneePain: 1, illness: false).save(db)
    }
    seed = nil
    let bytesBefore = try Data(contentsOf: URL(fileURLWithPath: path))

    // The open fails with a transient, lockable condition — NOT corruption.
    let recorder = LogRecorder()
    let client = withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      DatabaseClient.makeLiveResilient(path: path) { _ in
        throw DatabaseError(resultCode: .SQLITE_BUSY, message: "raw sqlite detail")
      }
    }

    // The session still gets a WORKING (in-memory) client…
    try await client.write { db in
      try CheckInRecord(date: Self.day, giSymptoms: true, kneePain: 3, illness: false).save(db)
    }
    let rows = try await client.read { db in try CheckInRecord.fetchAll(db) }
    #expect(rows.count == 1, "the in-memory fallback accepts reads and writes")

    // …and the on-disk file is BYTE-IDENTICAL: never quarantined, never recreated.
    let bytesAfter = try Data(contentsOf: URL(fileURLWithPath: path))
    #expect(bytesAfter == bytesBefore, "a transient open failure must not touch the on-disk file")
    #expect(!FileManager.default.fileExists(atPath: path + ".corrupt"), "no quarantine artifact appears")

    // The preserve decision is recorded on `.http` (always on), write-loss explicit, result code
    // only — no raw error payload.
    let entry = try #require(recorder.entries.first)
    #expect(entry.category == .http)
    #expect(entry.message.contains("file preserved"))
    #expect(entry.message.contains("NEW WRITES WILL NOT PERSIST"))
    #expect(entry.message.contains(ResultCode.SQLITE_BUSY.description))
    #expect(!entry.message.contains("raw sqlite detail"))
  }

  /// Phase 18.4 quarantine-then-failing-recreate: proven corruption quarantines (ALL FOUR sidecar
  /// suffixes — the injected open never touches the filesystem, so the move set is deterministic
  /// here), but when the recreate attempt ALSO fails the record must say so — never a false
  /// "recreated" — and the session falls back to in-memory.
  @Test func test_makeLiveResilient_corruptThenFailingRecreate_logsFailureAndFallsBackInMemory() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("makeLiveResilientTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("coachapp.sqlite").path
    try Data("not a database".utf8).write(to: URL(fileURLWithPath: path))
    for suffix in ["-journal", "-wal", "-shm"] {
      try Data("sidecar".utf8).write(to: URL(fileURLWithPath: path + suffix))
    }

    // Stateful injected open: proven corruption first, then a transient failure on the recreate.
    let recorder = LogRecorder()
    var calls = 0
    let client = withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      DatabaseClient.makeLiveResilient(path: path) { _ in
        calls += 1
        if calls == 1 { throw DatabaseError(resultCode: .SQLITE_CORRUPT) }
        throw DatabaseError(resultCode: .SQLITE_BUSY)
      }
    }
    #expect(calls == 2, "quarantine is followed by exactly ONE recreate attempt")

    // Quarantine DID fire (the first failure was proven corruption): all four suffixes moved aside.
    for suffix in ["", "-journal", "-wal", "-shm"] {
      #expect(
        FileManager.default.fileExists(atPath: path + suffix + ".corrupt"),
        "the '\(suffix)' file is quarantined to a .corrupt sibling"
      )
      #expect(
        !FileManager.default.fileExists(atPath: path + suffix),
        "the '\(suffix)' file is moved, not copied"
      )
    }

    // …the in-memory last resort still works…
    try await client.write { db in
      try CheckInRecord(date: Self.day, giSymptoms: false, kneePain: 0, illness: false).save(db)
    }
    let rows = try await client.read { db in try CheckInRecord.fetchAll(db) }
    #expect(rows.count == 1, "the in-memory fallback accepts reads and writes")

    // …and the record is the recreate-FAILURE one, carrying BOTH result codes, on `.http`.
    let entry = try #require(recorder.entries.first)
    #expect(entry.category == .http)
    #expect(entry.message.contains("recreate FAILED"))
    #expect(!entry.message.hasSuffix("recreated"), "a failed recreate must never read as success")
    #expect(entry.message.contains(ResultCode.SQLITE_CORRUPT.description))
    #expect(entry.message.contains(ResultCode.SQLITE_BUSY.description))
    #expect(entry.message.contains("in-memory"))
  }
}
