import Dependencies
import Foundation
import GRDB

extension Database: TestDependencyKey {
  /// An in-memory queue with **no** migrations (the migrated in-memory fixture is
  /// `DatabaseClient.makeInMemory()` — the migrations live alongside this in the same module per
  /// Decision #1). This is the swift-dependencies default; DB-backed tests inject a migrated `Database`.
  public static var testValue: Database {
    // swiftlint:disable:next force_try
    let queue = try! DatabaseQueue()
    return Database(reader: { queue }, writer: { queue })
  }

  public static var previewValue: Database { testValue }
}
