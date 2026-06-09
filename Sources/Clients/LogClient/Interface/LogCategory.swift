/// The subsystem a log entry belongs to. The `rawValue` string is the stable key the persisted
/// `DevSettings` per-category toggle is keyed by (so `DevSettings` need not import `LogClient` —
/// DECISIONS 3). `.http` is **always on** (`isAlwaysOn`); the gate in `LogClientLive` honours this
/// and lets every other category be toggled by the persisted `DevSettings` flag.
public enum LogCategory: String, Sendable, CaseIterable {
  case http
  case tca
  case lifecycle
  case app

  /// The single source of the always-on rule: `.http` bypasses the category gate (it is the network
  /// observability backbone and ships on by default); all other categories are gated.
  public var isAlwaysOn: Bool { self == .http }
}
