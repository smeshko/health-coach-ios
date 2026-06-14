import Foundation
import GRDB
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
}
