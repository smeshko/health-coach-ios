import Database
import Dependencies
import Foundation
import GRDB

// `Database` is ambiguous in this file (this module's client struct vs `GRDB.Database`), so the
// client is referenced via the `DatabaseClient` alias the interface exports.
public extension DatabaseClient {
  /// Open (or create) the on-disk SQLite database at `path` and run migrations.
  static func makeLive(path: String) throws -> DatabaseClient {
    let queue = try DatabaseQueue(path: path)
    try migrator.migrate(queue)
    return make(queue: queue)
  }

  /// A migrated in-memory database — the fixture DB-backed tests use.
  static func makeInMemory() throws -> DatabaseClient {
    let queue = try DatabaseQueue()
    try migrator.migrate(queue)
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

  /// Open the on-disk DB **with a corruption fallback** (CR-2, release audit 2026-06-18). A bare
  /// `makeLive` throws when the file is corrupt or an existing-file migration fails — which, on the
  /// launch path, is an unrecoverable crash-loop the user can only escape by deleting + reinstalling
  /// the app (losing everything). Instead: open the existing file; on failure quarantine it (move it
  /// aside) and recreate an empty one; if even that fails, fall back to an in-memory DB so the app still
  /// launches. Every table is a re-derivable cache or locally re-enterable state (briefs/zones re-fetch;
  /// a check-in / strength test can be re-entered) — never the account — so a one-time reset is strictly
  /// better than a brick. The Keychain bearer token is untouched, so the user stays signed in.
  static func makeLiveResilient(path: String) -> DatabaseClient {
    if let db = try? makeLive(path: path) { return db }
    quarantineDatabaseFile(at: path)
    if let db = try? makeLive(path: path) { return db }
    // Last resort: an ephemeral DB so launch never crashes. Persistence is lost for this session, but
    // the next launch retries the (now-quarantined, freshly creatable) on-disk path. `makeInMemory`
    // can only fail on a fundamentally broken SQLite environment, where crashing is the honest outcome.
    // swiftlint:disable:next force_try
    return try! makeInMemory()
  }

  /// Move a bad DB file (and its `-wal`/`-shm` siblings) aside so the next `makeLive` can create a fresh
  /// one. Best-effort (`try?`): a missing file or a failed move just means the recreate attempt runs on
  /// whatever is there. A fixed `.corrupt` suffix overwrites any prior quarantine (no unbounded growth).
  private static func quarantineDatabaseFile(at path: String) {
    let fileManager = FileManager.default
    for suffix in ["", "-wal", "-shm"] {
      let source = path + suffix
      let destination = path + suffix + ".corrupt"
      try? fileManager.removeItem(atPath: destination)
      try? fileManager.moveItem(atPath: source, toPath: destination)
    }
  }
}

extension DatabaseClient: DependencyKey {
  /// On-disk, with a corruption fallback (CR-2). The composition root (Epic 06) may override with an
  /// explicit path. A failure to even resolve the Application Support directory (no writable storage)
  /// falls back to in-memory rather than crashing the launch.
  public static var liveValue: DatabaseClient {
    guard let path = try? defaultDatabasePath() else {
      // swiftlint:disable:next force_try
      return try! makeInMemory()
    }
    return makeLiveResilient(path: path)
  }
}
