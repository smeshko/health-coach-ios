import Database
import Dependencies
import Foundation
import GRDB

// `Database` is ambiguous in this file (this module's client struct vs `GRDB.Database`), so the
// client is referenced via the `DatabaseClient` alias the interface exports.
public extension DatabaseClient {
  /// Open (or create) the on-disk SQLite database at `path`. Migrations are run by ``makeLive`` /
  /// ``makeInMemory`` once the migrator is wired (TASK-002).
  static func makeLive(path: String) throws -> DatabaseClient {
    let queue = try DatabaseQueue(path: path)
    return make(queue: queue)
  }

  /// An in-memory database (migrated once the migrator is wired) — the fixture DB-backed tests use.
  static func makeInMemory() throws -> DatabaseClient {
    let queue = try DatabaseQueue()
    return make(queue: queue)
  }

  /// Wrap a queue as a `Database` client (the queue is both reader and writer).
  static func make(queue: DatabaseQueue) -> DatabaseClient {
    DatabaseClient(reader: { queue }, writer: { queue })
  }

  /// The default on-disk location under Application Support.
  static func defaultDatabasePath() throws -> String {
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    )
    return directory.appendingPathComponent("coachapp.sqlite").path
  }
}

extension DatabaseClient: DependencyKey {
  /// On-disk. The composition root (Epic 06) may override with an explicit path; a failure to open
  /// the live database at startup is an unrecoverable configuration error.
  public static var liveValue: DatabaseClient {
    // swiftlint:disable:next force_try
    try! makeLive(path: defaultDatabasePath())
  }
}
