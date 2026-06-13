#if DEBUG
  import ComposableArchitecture
  import Foundation
  import LogClient
  import Testing

  @testable import SettingsFeature

  /// `TestStore` coverage for the DEBUG log viewer: `.onAppear` / `.refreshTapped` load + parse recent
  /// lines from `@Dependency(\.log).readRecent()` and re-anchor the date cutoffs to `@Dependency(\.date)`;
  /// `.clearTapped` wipes the on-disk files (via `LogClient.clear`) and empties the list; the filter
  /// actions update state; and `filteredEntries` applies the level / category / query / date filters over
  /// the parsed entries (timestamps parsed in the canonical Europe/Sofia frame).
  @MainActor
  struct LogViewerFeatureTests {
    private let sample = [
      "2026-06-10 12:00:00.000 DEBUG [tca] AppFeature.onAppear",
      "2026-06-10 12:00:01.000 NOTICE [http] GET /probe → 200 — ms=84",
      "2026-06-10 12:00:02.000 ERROR [http] GET /brief → 401 — status=401",
      "2026-06-10 12:00:03.000 INFO [app] sync finished",
    ]
    /// A fixed "now" for the date-capture assertions (the exact instant is irrelevant — only that the
    /// reducer stamps `referenceDate` from `@Dependency(\.date)`).
    private let now = Date(timeIntervalSince1970: 1_749_556_800)

    @Test func test_onAppear_loadsParsesAndAnchorsDate() async {
      // `.onAppear` and `.refreshTapped` are literally one combined reducer case, so this test also
      // covers the former test_refreshTapped_reloadsLines (audit MERGE): the second send below re-loads
      // a fresh line set over the already-loaded entries via `.refreshTapped`.
      let lines = sample
      let fresh = LockIsolated(sample)
      let store = TestStore(initialState: LogViewerFeature.State()) {
        LogViewerFeature()
      } withDependencies: {
        $0.date = .constant(now)
        $0.log.readRecent = { fresh.value }
      }

      await store.send(.onAppear) {
        $0.isLoading = true
        $0.referenceDate = now
      }
      await store.receive(\.logsLoaded) {
        $0.isLoading = false
        $0.entries = LogViewerFeature.State.parse(lines)
      }

      // Refresh re-loads the (now different) recent lines over the existing entries — same reducer case.
      let freshLines = ["2026-06-10 13:00:00.000 INFO [app] fresh"]
      fresh.setValue(freshLines)
      await store.send(.refreshTapped) {
        $0.isLoading = true
        $0.referenceDate = now
      }
      await store.receive(\.logsLoaded) {
        $0.isLoading = false
        $0.entries = LogViewerFeature.State.parse(freshLines)
      }
    }

    @Test func test_clearTapped_clearsFilesAndEntries() async {
      let cleared = LockIsolated(false)
      let store = TestStore(initialState: LogViewerFeature.State(lines: sample)) {
        LogViewerFeature()
      } withDependencies: {
        $0.log.clear = { cleared.setValue(true) }
      }

      await store.send(.clearTapped)
      await store.receive(\.logsCleared) { $0.entries = [] }
      await store.finish()

      #expect(cleared.value, "clearTapped must clear the on-disk logs")
    }

    @Test func test_filteredEntries_appliesLevelCategoryAndQuery() {
      var state = LogViewerFeature.State(lines: sample)

      // Minimum severity = error → only the 401 line survives.
      state.minLevel = .error
      #expect(state.filteredEntries.map(\.category) == [.http])

      // Category filter = app only.
      state.minLevel = .debug
      state.enabledCategories = [.app]
      #expect(state.filteredEntries.map(\.message) == ["sync finished"])

      // Free-text search matches the whole rendered line (metadata included).
      state.enabledCategories = Set(LogCategory.allCases)
      state.query = "status=401"
      #expect(state.filteredEntries.count == 1)
      #expect(state.filteredEntries.first?.level == .error)
    }

    @Test func test_filteredEntries_appliesDateRange() {
      let lines = [
        "2026-06-09 23:30:00.000 INFO [app] yesterday late",
        "2026-06-10 08:00:00.000 INFO [app] this morning",
        "2026-06-10 12:00:00.000 ERROR [http] just now",
      ]
      var state = LogViewerFeature.State(lines: lines)
      // Anchor "now" at 12:30 on 2026-06-10 (Sofia), the same frame timestamps are parsed in.
      state.referenceDate = LogTimestamp.parse("2026-06-10 12:30:00.000")!

      // `.today` drops the previous calendar day (Sofia start-of-day cutoff).
      state.dateRange = .today
      #expect(state.filteredEntries.map(\.message) == ["this morning", "just now"])

      // `.lastHour` keeps only the 12:00 entry (cutoff 11:30).
      state.dateRange = .lastHour
      #expect(state.filteredEntries.map(\.message) == ["just now"])

      // `.all` shows everything, including the unparsed-date case left untouched.
      state.dateRange = .all
      #expect(state.filteredEntries.count == 3)
    }

    /// Audit gap (cheap residual): exercise the `.last15min` / `.last24h` cutoffs (only `.today` /
    /// `.lastHour` / `.all` were covered).
    @Test func test_filteredEntries_last15minAndLast24h() {
      let lines = [
        "2026-06-09 11:00:00.000 INFO [app] yesterday morning", // before the 24h cutoff (yesterday 12:30)
        "2026-06-10 08:00:00.000 INFO [app] this morning", // inside 24h, outside 15min
        "2026-06-10 12:20:00.000 ERROR [http] ten minutes ago", // inside the 15min window
      ]
      var state = LogViewerFeature.State(lines: lines)
      state.referenceDate = LogTimestamp.parse("2026-06-10 12:30:00.000")!

      // `.last15min` (cutoff 12:15) keeps only the 12:20 entry.
      state.dateRange = .last15min
      #expect(state.filteredEntries.map(\.message) == ["ten minutes ago"])

      // `.last24h` (cutoff yesterday 12:30) drops the 13:00 entry from the day before.
      state.dateRange = .last24h
      #expect(state.filteredEntries.map(\.message) == ["this morning", "ten minutes ago"])
    }

    @Test func test_filteredEntries_dropsUndatedLinesUnderActiveDateRange() {
      // A legacy time-only line (written before the date was added to the format → no parseable date)
      // mixed with a dated one.
      let lines = [
        "12:00:00.000 INFO [app] legacy time-only line",
        "2026-06-10 12:00:00.000 INFO [app] dated line",
      ]
      var state = LogViewerFeature.State(lines: lines)
      state.referenceDate = LogTimestamp.parse("2026-06-10 12:30:00.000")!

      // `.all` (no cutoff) keeps both — an undated line is shown when no time filter is active.
      state.dateRange = .all
      #expect(state.filteredEntries.count == 2)

      // Any active range drops the undated line: it can't be confirmed to fall inside the window, and
      // keeping it is what made legacy lines defeat the time filter entirely.
      state.dateRange = .today
      #expect(state.filteredEntries.map(\.message) == ["dated line"])
    }
  }
#endif
