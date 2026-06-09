import Dependencies
import Foundation

extension LogClient: TestDependencyKey {
  /// Records every emitted entry into a fresh `LogRecorder`. Tests that need to assert on the
  /// captured entries inject their own recorder via `LogClient.recording(into:)` (see below) so they
  /// hold the handle; the bare `testValue` is the safe default for code under test that does not
  /// assert on logs. (No `liveValue` here — that is `LogClientLive`, TASK-002.)
  public static var testValue: LogClient {
    .recording(into: LogRecorder())
  }

  /// Previews log nothing.
  public static var previewValue: LogClient {
    LogClient(log: { _, _, _, _ in })
  }
}

public extension LogClient {
  /// A `LogClient` that appends every emitted entry into `recorder` — the host-assertable seam. Tests
  /// build a `LogRecorder`, inject `.recording(into:)`, exercise the code, then assert on
  /// `recorder.entries`.
  static func recording(into recorder: LogRecorder) -> LogClient {
    LogClient(log: { level, category, message, metadata in
      recorder.record(.init(level: level, category: category, message: message, metadata: metadata))
    })
  }
}

/// In-memory, synchronous recorder of log entries for host assertions. The `log` closure is
/// synchronous and non-throwing, so the recorder is a lock-backed `@unchecked Sendable` class
/// (mirroring `DevSettingsStore`) rather than an `actor`: it appends and reads synchronously, so a
/// test can assert immediately after the log call with no `await` and no race.
public final class LogRecorder: @unchecked Sendable {
  /// One captured log emission.
  public struct Entry: Sendable, Equatable {
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let metadata: [String: String]

    public init(level: LogLevel, category: LogCategory, message: String, metadata: [String: String]) {
      self.level = level
      self.category = category
      self.message = message
      self.metadata = metadata
    }
  }

  private let lock = NSLock()
  private var _entries: [Entry] = []

  public init() {}

  public func record(_ entry: Entry) {
    lock.withLock { _entries.append(entry) }
  }

  /// A snapshot of the entries captured so far.
  public var entries: [Entry] {
    lock.withLock { _entries }
  }
}
