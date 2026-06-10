import CoachCore
import Foundation
import Logging

/// A `swift-log` `LogHandler` that renders one human-readable line per entry and fans it out to both
/// the console (stdout) and the rotating `LogFileWriter`. Format:
///
///     yyyy-MM-dd HH:mm:ss.SSS LEVEL [category] message — key=value key=value …
///
/// The category is carried in metadata under `categoryKey` (the live `LogClient` injects
/// `LogCategory.rawValue` there) and stripped from the rendered `key=value` tail. Timestamps are the
/// full local date+time in the app's canonical Europe/Sofia frame (`Calendar.europeSofia` — the same
/// value `useEuropeSofia()` pins `\.calendar` to), so both the Xcode console and the DEBUG log viewer
/// read in wall-clock time and the viewer parses them back in the identical frame. A `Calendar` is a
/// `Sendable` value type, so this stays thread-safe with no shared mutable `DateFormatter`, and it makes
/// DST correct (unlike a fixed UTC offset). The fixed-width prefix keeps the line machine-parseable for
/// the viewer's filters. This handler also backs the process-global `LoggingSystem.bootstrap`
/// (TASK-004), so stray third-party swift-log loggers land in the same console+file sink.
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

  /// `yyyy-MM-dd HH:mm:ss.SSS` in the canonical `Calendar.europeSofia` frame. A `Calendar` is a
  /// `Sendable` value type that knows the zone's DST rules, so this stays thread-safe to call from the
  /// arbitrary thread `log(…)` runs on (no shared `DateFormatter`). The fixed-width layout keeps the
  /// line parseable by the viewer's filters.
  static func timestamp(_ date: Date) -> String {
    let parts = Calendar.europeSofia.dateComponents(
      [.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date
    )
    let millis = (parts.nanosecond ?? 0) / 1_000_000
    return String(
      format: "%04d-%02d-%02d %02d:%02d:%02d.%03d",
      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, millis
    )
  }
}
