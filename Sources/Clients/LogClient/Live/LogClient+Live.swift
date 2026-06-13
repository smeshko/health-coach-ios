import Dependencies
import DevSettings
import Foundation
import LogClient

extension LogClient: DependencyKey {
  /// The live logger: console + rotating file (via the process-shared `LogFileWriter`), with category
  /// gating read from the persisted `DevSettings` toggles **per emit** (so a future 7.4 switch takes
  /// effect immediately and the gate is host-injectable). `.http` is always on; other categories are
  /// emitted only when their `DevSettings` flag is enabled (and in RELEASE every verbose category
  /// resolves to off, since `DevSettings` is a hard no-op there).
  public static var liveValue: LogClient {
    live(writer: .shared)
  }

  /// Builds a live `LogClient` over `writer` (+ console sink). Factored out so tests can point it at a
  /// temp directory and assert on the file. Not for app use — the app uses `liveValue`.
  ///
  /// The `log` closure renders the line directly and fans it out to the console + rotating file — there
  /// is no `swift-log` indirection (DECISIONS D1: the capture layer served third-party `Logger(label:)`
  /// emitters that don't exist in the dependency tree). The rendered shape is
  /// `yyyy-MM-dd HH:mm:ss.SSS LEVEL [category] message — key=value …` (metadata keys sorted), the
  /// timestamp in the canonical `Calendar.europeSofia` frame via `LogTimestamp` — byte-identical to the
  /// pre-11.5 handler output, so the DEBUG log viewer still parses it.
  static func live(
    writer: LogFileWriter,
    console: @escaping @Sendable (String) -> Void = { print($0) }
  ) -> LogClient {
    LogClient(
      log: { level, category, message, metadata in
        @Dependency(\.devSettings) var devSettings
        guard category.isAlwaysOn || devSettings.isLogCategoryEnabled(category.rawValue) else { return }

        let line = render(level: level, category: category, message: message, metadata: metadata)
        console(line)
        writer.enqueue(line)
      },
      // The DEBUG log viewer (Phase 7.4) reads the rotating files back through the same writer.
      readRecent: { await writer.recentLines() },
      // …and clears them through the same writer (FIFO-ordered after any in-flight append).
      clear: { await writer.clear() }
    )
  }

  /// Render one log line: `yyyy-MM-dd HH:mm:ss.SSS LEVEL [category] message — key=value …`, the
  /// timestamp in the Europe/Sofia frame (`LogTimestamp`) and the metadata pairs sorted by key. The
  /// level token matches the pre-11.5 handler output (swift-log's `rawValue.uppercased()`).
  static func render(
    level: LogLevel, category: LogCategory, message: String, metadata: [String: String]
  ) -> String {
    var line = "\(LogTimestamp.format(Date())) \(level.token) [\(category.rawValue)] \(message)"
    if !metadata.isEmpty {
      let pairs = metadata.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
      line += " — \(pairs)"
    }
    return line
  }
}

private extension LogLevel {
  /// The rendered level token — byte-identical to the pre-11.5 handler, which uppercased swift-log's
  /// `Logger.Level.rawValue` (`debug`/`info`/`notice`/`error`).
  var token: String {
    switch self {
    case .debug: "DEBUG"
    case .info: "INFO"
    case .notice: "NOTICE"
    case .error: "ERROR"
    }
  }
}
