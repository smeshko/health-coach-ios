import Dependencies
import Foundation
import GRDB

/// The dumb persistence data source — a `Sendable` value owning access to a single GRDB queue via
/// `reader`/`writer` closures, with generic typed `read`/`write`/`observe` facade methods that run a
/// caller-supplied transaction block (Decision #2 — swift-dependencies stored closures can't be
/// generic, so genericity lives in these methods, mirroring `APIClient.send<R>`).
///
/// No domain methods, no cache policy: repositories (Epic 04) layer typed entity access on top
/// (§6/D9). Migrations + the queue itself live in `DatabaseLive`.
public struct Database: Sendable {
  /// The read connection (a `DatabaseQueue` is both reader and writer).
  public var reader: @Sendable () -> any DatabaseReader
  /// The write connection.
  public var writer: @Sendable () -> any DatabaseWriter

  public init(
    reader: @escaping @Sendable () -> any DatabaseReader,
    writer: @escaping @Sendable () -> any DatabaseWriter
  ) {
    self.reader = reader
    self.writer = writer
  }

  /// Run a read-only transaction block and return its typed result.
  public func read<T: Sendable>(_ work: @escaping @Sendable (GRDB.Database) throws -> T) async throws -> T {
    try await reader().read(work)
  }

  /// Run a write transaction block (atomic) and return its typed result.
  public func write<T: Sendable>(_ work: @escaping @Sendable (GRDB.Database) throws -> T) async throws -> T {
    try await writer().write(work)
  }

  /// Observe a query: emits the initial value, then a fresh value whenever the query's result
  /// changes (GRDB `ValueObservation` bridged to `AsyncStream`). The observation is cancelled when
  /// the consuming `Task` is cancelled (the stream's `onTermination`).
  public func observe<T: Sendable>(
    _ fetch: @escaping @Sendable (GRDB.Database) throws -> T
  ) -> AsyncStream<T> {
    let observedReader = reader()
    let observation = ValueObservation.tracking(fetch)
    return AsyncStream { continuation in
      let task = Task {
        do {
          for try await value in observation.values(in: observedReader) {
            continuation.yield(value)
          }
        } catch {
          // Observation error → end the stream (a mapping/DB failure surfaces upstream, not a crash).
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

public extension DependencyValues {
  var database: Database {
    get { self[Database.self] }
    set { self[Database.self] = newValue }
  }
}

/// Unambiguous alias for the client struct. Consumers that also `import GRDB` (e.g. `DatabaseLive`,
/// repositories) hit a name clash between this module's `Database` type and `GRDB.Database`; refer to
/// the client as `DatabaseClient` there. Resolved here, where the local `Database` shadows GRDB's.
public typealias DatabaseClient = Database
