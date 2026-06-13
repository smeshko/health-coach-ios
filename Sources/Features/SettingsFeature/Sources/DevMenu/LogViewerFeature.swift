#if DEBUG
  import CoachCore
  import ComposableArchitecture
  import Foundation
  import LogClient

  /// The DEBUG on-device log viewer (Phase 7.4). Loads recent log lines from
  /// `@Dependency(\.log).readRecent()` — the live `LogClient` reads the rotating `Caches/Logs/` files —
  /// parses each into a `LogEntry` (timestamp / level / category / message / `Date`) so the screen can
  /// **filter** by date range, category, minimum severity and free-text search, **clear** the on-disk
  /// files, and re-load on demand. Read-only apart from `clear`; the whole file is `#if DEBUG`, so it
  /// compiles out of RELEASE. It touches only the `LogClient` **interface** (no `*Live`), so the next
  /// reload reflects whatever has been written since.
  @Reducer
  public struct LogViewerFeature {
    @ObservableState
    public struct State: Equatable {
      /// Parsed log entries, oldest→newest (the view renders them newest-first).
      public var entries: [LogEntry] = []
      public var isLoading = false
      /// Free-text filter matched against the whole rendered line (case-insensitive).
      public var query = ""
      /// Minimum severity shown — entries below this level are hidden.
      public var minLevel: LogLevel = .debug
      /// Which categories are shown. Starts with all enabled; chips toggle membership.
      public var enabledCategories: Set<LogCategory> = Set(LogCategory.allCases)
      /// The active date-range preset; cutoffs are measured against `referenceDate`.
      public var dateRange: DateRange = .all
      /// "Now" as of the last load/refresh — the anchor the relative `dateRange` cutoffs are measured
      /// from (captured via `@Dependency(\.date)`, so Refresh re-anchors "Last 15 min" to the present).
      public var referenceDate: Date = .distantPast

      public init(lines: [String] = []) {
        entries = Self.parse(lines)
      }

      /// The entries surviving the active filters (oldest→newest). A line with no parseable level or
      /// category is kept (better to show a stray line than hide it) — but when a date range is active, a
      /// line whose timestamp didn't parse is **dropped**: it can't be confirmed to fall inside the range,
      /// and keeping such lines is what made legacy time-only entries (written before the date was added
      /// to the format) defeat the time filter entirely. `.all` (no cutoff) still shows everything.
      public var filteredEntries: [LogEntry] {
        let cutoff = dateRange.cutoff(now: referenceDate)
        return entries.filter { entry in
          let levelOK = entry.level.map { $0.severity >= minLevel.severity } ?? true
          let categoryOK = entry.category.map { enabledCategories.contains($0) } ?? true
          let queryOK = query.isEmpty || entry.raw.localizedCaseInsensitiveContains(query)
          let dateOK = cutoff.map { limit in entry.date.map { $0 >= limit } ?? false } ?? true
          return levelOK && categoryOK && queryOK && dateOK
        }
      }

      /// Parse rendered lines (`<timestamp> LEVEL [category] message …`) into entries, tagging each with
      /// its source index as a stable identity.
      static func parse(_ lines: [String]) -> [LogEntry] {
        lines.enumerated().map { LogEntry(id: $0.offset, line: $0.element) }
      }
    }

    public enum Action: Equatable {
      case onAppear
      case refreshTapped
      case clearTapped
      case logsLoaded([String])
      case logsCleared
      case queryChanged(String)
      case minLevelChanged(LogLevel)
      case categoryToggled(LogCategory)
      case dateRangeChanged(DateRange)
    }

    @Dependency(\.log) var log
    @Dependency(\.date) var date

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear, .refreshTapped:
          state.isLoading = true
          // Re-anchor the relative date cutoffs to "now" on every (re)load.
          state.referenceDate = date.now
          return .run { [log] send in
            await send(.logsLoaded(log.readRecent()))
          }
        case let .logsLoaded(lines):
          state.isLoading = false
          state.entries = State.parse(lines)
          return .none
        case .clearTapped:
          // Wipe the on-disk files, then drop the in-memory entries on the reply so the list empties.
          return .run { [log] send in
            await log.clear()
            await send(.logsCleared)
          }
        case .logsCleared:
          state.entries = []
          return .none
        case let .queryChanged(query):
          state.query = query
          return .none
        case let .minLevelChanged(level):
          state.minLevel = level
          return .none
        case let .categoryToggled(category):
          if state.enabledCategories.contains(category) {
            state.enabledCategories.remove(category)
          } else {
            state.enabledCategories.insert(category)
          }
          return .none
        case let .dateRangeChanged(range):
          state.dateRange = range
          return .none
        }
      }
    }
  }

  /// A relative "newer than" date filter for the log viewer. Cutoffs are measured against a supplied
  /// "now" (`State.referenceDate`), so the filter stays a pure function of state — the clock is read
  /// once, in the reducer, via `@Dependency(\.date)`.
  public enum DateRange: String, CaseIterable, Equatable, Sendable {
    case all
    case last15min
    case lastHour
    case today
    case last24h

    /// The oldest timestamp shown for this range, or `nil` (`.all`) to show everything. `.today` is the
    /// start of the calendar day in the app's pinned Europe/Sofia frame; the rest are simple offsets
    /// from `now`.
    func cutoff(now: Date) -> Date? {
      switch self {
      case .all: nil
      case .last15min: now.addingTimeInterval(-15 * 60)
      case .lastHour: now.addingTimeInterval(-60 * 60)
      case .today: Calendar.europeSofia.startOfDay(for: now)
      case .last24h: now.addingTimeInterval(-24 * 60 * 60)
      }
    }
  }

  /// One parsed log line. `raw` is the full rendered string (used verbatim for search and as the
  /// fallback when a line doesn't match the expected shape); `timestamp`/`level`/`category`/`message`
  /// are the split-out parts the styled row renders, and `date` is the parsed timestamp the date filter
  /// compares. `id` is the source index, giving stable identity.
  public struct LogEntry: Equatable, Identifiable, Sendable {
    public let id: Int
    public let timestamp: String
    public let level: LogLevel?
    public let category: LogCategory?
    public let message: String
    public let date: Date?
    public let raw: String

    /// Parse a rendered line of the form `<timestamp> LEVEL [category] message …`. The category is the
    /// first `[...]` group; the level is the last whitespace token before it; the timestamp is the rest
    /// of the head. A line that doesn't fit (e.g. a stray third-party logger line) keeps `raw` only.
    init(id: Int, line: String) {
      self.id = id
      raw = line
      guard
        let open = line.firstIndex(of: "["),
        let close = line[open...].firstIndex(of: "]")
      else {
        timestamp = ""
        level = nil
        category = nil
        message = line
        date = nil
        return
      }
      let head = line[..<open].split(separator: " ")
      level = head.last.flatMap { LogLevel(token: String($0)) }
      let stamp = head.dropLast().joined(separator: " ")
      timestamp = stamp
      // The timestamp contract has one owner (`LogTimestamp`, in the LogClient interface) — the same
      // helper the live renderer formats with, so parse and render agree on the Europe/Sofia frame.
      date = LogTimestamp.parse(stamp)
      category = LogCategory(rawValue: String(line[line.index(after: open)..<close]))
      message = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
    }
  }

  extension LogLevel {
    /// Ordering for the minimum-severity filter (`debug` < `info` < `notice` < `error`).
    var severity: Int {
      switch self {
      case .debug: 0
      case .info: 1
      case .notice: 2
      case .error: 3
      }
    }

    /// The display order for the level picker (least→most severe).
    static let ordered: [LogLevel] = [.debug, .info, .notice, .error]

    /// Map a rendered level token back to a `LogLevel`. The live renderer emits uppercased tokens
    /// (`DEBUG`/`INFO`/`NOTICE`/`ERROR`); the rarer tokens a legacy line might carry
    /// (`TRACE`/`WARNING`/`CRITICAL`) fold into the nearest level so they still surface.
    init?(token: String) {
      switch token.uppercased() {
      case "DEBUG", "TRACE": self = .debug
      case "INFO": self = .info
      case "NOTICE": self = .notice
      case "ERROR", "WARNING", "CRITICAL": self = .error
      default: return nil
      }
    }
  }
#endif
