import Dependencies
import DevSettings
import Foundation
import LogClient
import Logging

extension LogClient: DependencyKey {
  /// The live logger: console + rotating file (via the process-shared `LogFileWriter`), with category
  /// gating read from the persisted `DevSettings` toggles **per emit** (so a future 7.4 switch takes
  /// effect immediately and the gate is host-injectable). `.http` is always on; other categories are
  /// emitted only when their `DevSettings` flag is enabled (and in RELEASE every verbose category
  /// resolves to off, since `DevSettings` is a hard no-op there).
  public static var liveValue: LogClient {
    live(writer: .shared)
  }

  /// One-shot, process-global swift-log bootstrap so any **stray** third-party `Logger(label:)` also
  /// lands in the same console+file sink. Call exactly once at app start (the composition root). The
  /// `LogClient.live` path builds its own `Logger` and does **not** depend on this — bootstrap only
  /// redirects loggers we don't own. Re-bootstrapping is the process-global double-bootstrap hazard.
  public static func bootstrapStandardLogging() {
    LoggingSystem.bootstrap { _ in
      CoachLogHandler(writer: .shared, console: { print($0) })
    }
  }

  /// Builds a live `LogClient` over `writer` (+ console sink). Factored out so tests can point it at a
  /// temp directory and assert on the file. Not for app use — the app uses `liveValue`.
  static func live(
    writer: LogFileWriter,
    console: @escaping @Sendable (String) -> Void = { print($0) }
  ) -> LogClient {
    let logger = Logger(label: "com.coach.app") { _ in
      CoachLogHandler(writer: writer, console: console)
    }
    return LogClient(
      log: { level, category, message, metadata in
        @Dependency(\.devSettings) var devSettings
        guard category.isAlwaysOn || devSettings.isLogCategoryEnabled(category.rawValue) else { return }

        var entryMetadata: Logger.Metadata = [CoachLogHandler.categoryKey: .string(category.rawValue)]
        for (key, value) in metadata {
          entryMetadata[key] = .string(value)
        }
        logger.log(level: level.loggerLevel, "\(message)", metadata: entryMetadata)
      },
      // The DEBUG log viewer (Phase 7.4) reads the rotating files back through the same writer.
      readRecent: { await writer.recentLines() }
    )
  }
}

private extension LogLevel {
  /// Map the app-facing level onto swift-log's.
  var loggerLevel: Logger.Level {
    switch self {
    case .debug: .debug
    case .info: .info
    case .notice: .notice
    case .error: .error
    }
  }
}
