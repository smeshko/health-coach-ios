/// Severity of a log entry. A small, app-facing level set that `LogClientLive` renders to an
/// uppercase token (`DEBUG`/`INFO`/`NOTICE`/`ERROR`). Plain enum (no associated values) so it is
/// automatically `Equatable`/`Hashable` for host assertions; no app types, so the interface stays
/// decoupled (DECISIONS 2).
public enum LogLevel: Sendable {
  case debug
  case info
  case notice
  case error
}
