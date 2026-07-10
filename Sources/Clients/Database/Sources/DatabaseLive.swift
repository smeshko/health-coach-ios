import Database
import Dependencies
import Foundation
import GRDB
import LogClient

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

  /// Open the on-disk DB **with a discriminating failure fallback** (CR-2, release audit 2026-06-18;
  /// discrimination added in Phase 18.4). A bare `makeLive` throws when the file is corrupt or an
  /// existing-file migration fails — which, on the launch path, is an unrecoverable crash-loop the user
  /// can only escape by deleting + reinstalling the app (losing everything). But failure ≠ corruption:
  /// quarantine-and-recreate fires **only on proven corruption** (`SQLITE_CORRUPT`/`SQLITE_NOTADB`) —
  /// there every table is a re-derivable cache or locally re-enterable state (briefs/zones re-fetch;
  /// a check-in / strength test can be re-entered), never the account, so a one-time reset is strictly
  /// better than a brick and the Keychain bearer token keeps the user signed in. **Every other failure**
  /// (busy/locked, I/O, disk-full, cantopen, a throwing migration bug, non-SQLite errors) PRESERVES the
  /// file untouched and degrades to an in-memory session — the next launch retries the healthy file —
  /// because wiping a healthy database over a transient condition is silent total data loss. Both
  /// outcomes are logged on the always-on `.http` category (`.app` is toggle-gated — 18.1 precedent).
  ///
  /// `open` is the injectable seam for tests to force classified failures; production callers use the
  /// default (`makeLive`).
  static func makeLiveResilient(
    path: String,
    open: (String) throws -> DatabaseClient = { try makeLive(path: $0) }
  ) -> DatabaseClient {
    @Dependency(\.log) var log
    do {
      return try open(path)
    } catch {
      switch classifyOpenFailure(error) {
      case .preserve:
        // Not proven corruption → never touch the disk file. The in-memory session accepts writes
        // that vanish at exit — the pre-existing last-resort semantics, made explicit in the record.
        log.error(
          "DB open failed (transient \(openFailureCode(error))) — file preserved, in-memory this "
            + "session; NEW WRITES WILL NOT PERSIST",
          category: .http,
          metadata: ["path": path]
        )
        // swiftlint:disable:next force_try
        return try! makeInMemory()
      case .quarantine:
        let corruptionCode = openFailureCode(error)
        quarantineDatabaseFile(at: path)
        do {
          let recreated = try open(path)
          log.error(
            "DB corrupt (\(corruptionCode)) — quarantined, recreated",
            category: .http,
            metadata: ["path": path]
          )
          return recreated
        } catch {
          // Last resort: an ephemeral DB so launch never crashes. Persistence is lost for this
          // session; the next launch retries the (now-quarantined, freshly creatable) on-disk path.
          // `makeInMemory` can only fail on a fundamentally broken SQLite environment, where crashing
          // is the honest outcome.
          log.error(
            "DB corrupt (\(corruptionCode)) — quarantined, recreate FAILED "
              + "(\(openFailureCode(error))), in-memory this session",
            category: .http,
            metadata: ["path": path]
          )
          // swiftlint:disable:next force_try
          return try! makeInMemory()
        }
      }
    }
  }

  /// Move a bad DB file (and its `-journal`/`-wal`/`-shm` siblings — `DatabaseQueue` runs in
  /// rollback-journal mode, so `-journal` is the sidecar that actually exists) aside so the next
  /// `makeLive` can create a fresh one. Best-effort (`try?`): a missing file or a failed move just means
  /// the recreate attempt runs on whatever is there. A fixed `.corrupt` suffix overwrites any prior
  /// quarantine (no unbounded growth).
  private static func quarantineDatabaseFile(at path: String) {
    let fileManager = FileManager.default
    for suffix in ["", "-journal", "-wal", "-shm"] {
      let source = path + suffix
      let destination = path + suffix + ".corrupt"
      try? fileManager.removeItem(atPath: destination)
      try? fileManager.moveItem(atPath: source, toPath: destination)
    }
  }
}

/// How `makeLiveResilient` recovers from a failed open (Phase 18.4): quarantine-and-recreate only on
/// proven corruption; preserve the file and degrade to in-memory on everything else.
enum OpenFailureRecovery: Equatable {
  case quarantine
  case preserve
}

extension DatabaseClient {
  /// Classify an open/migrate failure. Only the proven-corruption **primary** result codes
  /// (`SQLITE_CORRUPT` 11, `SQLITE_NOTADB` 26 — extended variants classify by their primary) warrant
  /// destroying the file; every other `DatabaseError` (busy/locked/ioerr/full/cantopen…) and every
  /// non-SQLite error (a throwing migration bug included) is conservatively `preserve`: an in-memory
  /// session is a bounded cost, wiping a healthy DB is not.
  static func classifyOpenFailure(_ error: Error) -> OpenFailureRecovery {
    guard let databaseError = error as? DatabaseError else { return .preserve }
    switch databaseError.resultCode {
    case .SQLITE_CORRUPT, .SQLITE_NOTADB:
      return .quarantine
    default:
      return .preserve
    }
  }

  /// A log-safe rendering of the failure: the SQLite result code (rawValue + errstr) for
  /// `DatabaseError`s, the bare error TYPE otherwise — never the error's own message/SQL payload.
  private static func openFailureCode(_ error: Error) -> String {
    if let databaseError = error as? DatabaseError {
      return databaseError.resultCode.description
    }
    return String(describing: type(of: error))
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
