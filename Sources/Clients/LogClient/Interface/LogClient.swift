import Dependencies
import Foundation

/// App-wide structured logging dependency (`@Dependency(\.log)`). A `Sendable` struct of a single
/// `@Sendable` log closure so the live backend (`LogClientLive`: console + rotating file + category
/// gating) and the test recorder swap cleanly — mirroring `TokenClient`/`APIClient` (DECISIONS 2).
///
/// The closure is **synchronous and non-throwing**: logging is fire-and-forget and must never block
/// or throw into the caller (the live handler does its file I/O off the calling thread). Call sites
/// use the level helpers (`error`/`notice`/`info`/`debug`); `.http` always logs, the other
/// categories are gated by the persisted `DevSettings` toggle inside `LogClientLive`.
public struct LogClient: Sendable {
  public typealias Log = @Sendable (
    _ level: LogLevel,
    _ category: LogCategory,
    _ message: String,
    _ metadata: [String: String]
  ) -> Void

  public var log: Log

  /// Reads recent persisted log lines (the current rotating file + its siblings, oldest→newest, capped)
  /// for the DEBUG on-device log viewer (Phase 7.4). Defaults to **empty** so the test / preview /
  /// recording values — and any cross-module fake — need not provide it; only `LogClientLive` reads the
  /// on-disk `Caches/Logs/` files. `async` because the live read hops onto the file-writer actor.
  public var readRecent: @Sendable () async -> [String]

  /// Deletes every persisted log file (the DEBUG log viewer's "Clear" action). Defaults to a **no-op**
  /// so the test / preview / recording values need not provide it; only `LogClientLive` wipes the
  /// on-disk `Caches/Logs/` files. `async` because the live clear is ordered after in-flight appends on
  /// the file-writer actor.
  public var clear: @Sendable () async -> Void

  public init(
    log: @escaping Log,
    readRecent: @escaping @Sendable () async -> [String] = { [] },
    clear: @escaping @Sendable () async -> Void = {}
  ) {
    self.log = log
    self.readRecent = readRecent
    self.clear = clear
  }
}

public extension LogClient {
  func error(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
    log(.error, category, message, metadata)
  }

  func notice(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
    log(.notice, category, message, metadata)
  }

  func info(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
    log(.info, category, message, metadata)
  }

  func debug(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
    log(.debug, category, message, metadata)
  }
}

public extension DependencyValues {
  var log: LogClient {
    get { self[LogClient.self] }
    set { self[LogClient.self] = newValue }
  }
}
