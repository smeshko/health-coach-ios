import Database
import DatabaseLive
import Foundation

// Shared in-memory test database convenience (Phase 11.6 / DECISIONS D1). `DatabaseLive` already
// ships `DatabaseClient.makeInMemory()` (a migrated in-memory queue); this is a thin re-export so
// repo Live test targets get the migrated fixture from one place without each re-importing
// `DatabaseLive`. Record-specific seed helpers stay local to each repo test target (they need that
// repo's `PersistenceModels` record types). Host-compiling: Database + GRDB only, no UIKit.

public enum TestDatabase {
  /// A migrated in-memory `Database` (runs the real `DatabaseLive` migrations). The `DatabaseClient`
  /// alias avoids the `Database` module-vs-`GRDB.Database` ambiguity at call sites that import both.
  public static func makeInMemory() throws -> DatabaseClient {
    try DatabaseClient.makeInMemory()
  }
}
