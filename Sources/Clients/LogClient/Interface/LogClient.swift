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

  public init(log: @escaping Log) {
    self.log = log
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
