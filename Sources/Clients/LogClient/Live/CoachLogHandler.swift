import Foundation
import Logging

/// A `swift-log` `LogHandler` that renders one human-readable line per entry and fans it out to both
/// the console (stdout) and the rotating `LogFileWriter`. Format:
///
///     HH:mm:ss.SSS LEVEL [category] message — key=value key=value …
///
/// The category is carried in metadata under `categoryKey` (the live `LogClient` injects
/// `LogCategory.rawValue` there) and stripped from the rendered `key=value` tail. Timestamps are UTC
/// and formatted with pure arithmetic so the handler stays `Sendable`/thread-safe (no shared
/// `DateFormatter`). This handler also backs the process-global `LoggingSystem.bootstrap` (TASK-004),
/// so stray third-party swift-log loggers land in the same console+file sink.
struct CoachLogHandler: LogHandler {
  /// The metadata key the live `LogClient` uses to carry `LogCategory.rawValue` to the formatter.
  static let categoryKey = "coach.category"

  var metadata: Logger.Metadata = [:]
  var logLevel: Logger.Level = .trace // we gate ourselves in `LogClient.live`; let everything through
  private let writer: LogFileWriter
  private let console: @Sendable (String) -> Void

  init(writer: LogFileWriter, console: @escaping @Sendable (String) -> Void) {
    self.writer = writer
    self.console = console
  }

  subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { metadata[key] }
    set { metadata[key] = newValue }
  }

  func log(event: LogEvent) {
    let merged = metadata.merging(event.metadata ?? [:]) { _, new in new }
    let formatted = Self.format(level: event.level, message: event.message.description, metadata: merged)
    console(formatted)
    writer.enqueue(formatted)
  }

  static func format(level: Logger.Level, message: String, metadata: Logger.Metadata) -> String {
    var meta = metadata
    let category = meta.removeValue(forKey: categoryKey).map { "\($0)" } ?? "log"
    var line = "\(timestamp(Date())) \(level.rawValue.uppercased()) [\(category)] \(message)"
    if !meta.isEmpty {
      let pairs = meta.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
      line += " — \(pairs)"
    }
    return line
  }

  /// `HH:mm:ss.SSS` (UTC) from pure arithmetic — no `DateFormatter`, so it is thread-safe to call from
  /// the arbitrary thread `log(…)` runs on.
  static func timestamp(_ date: Date) -> String {
    let totalMillis = Int((date.timeIntervalSince1970 * 1000).rounded(.down))
    let millis = totalMillis % 1000
    let totalSeconds = totalMillis / 1000
    let seconds = totalSeconds % 60
    let minutes = (totalSeconds / 60) % 60
    let hours = (totalSeconds / 3600) % 24
    return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
  }
}
