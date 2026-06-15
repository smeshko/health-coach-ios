import BriefRepository
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import Sharing

/// The "This Week" tab's root reducer (ARCHITECTURE §4.5/§8/§11, PRD §7.5) — the menu-with-budgets weekly
/// plan screen (the 2026-06-10 design iteration). It owns the universal `WeeklyViewState` lifecycle (the
/// single source of truth, DECISIONS #1) and the client-side new-ISO-week detection (§17.2) that triggers
/// the get-or-cache weekly fetch. The per-ISO-week cache itself lives in `BriefRepositoryLive` (D9 / 4.2) —
/// the feature always calls `weeklyBrief(isoWeek: nil, refresh: false)` on appear and lets the repo decide
/// fetch-vs-serve (DECISIONS #4); the new-week watermark drives the *moment* + the freshness label, not the
/// call. The 9.2 core/extra session groups + targets and the 9.3 weekly nutrition + adherence plug into
/// stable seams under `ready`.
///
/// **Feature dependency rule (§3):** imports only the repo **interfaces** (`BriefRepository` /
/// `ProfileRepository`, via `@Dependency`) + `DesignSystem` + `DomainModels` + `CoachCore` +
/// `ComposableArchitecture` (+ `Sharing` for the persisted watermark) — never a `*Live`, data-source
/// client, `WireModels`, GRDB, or HealthKit.
@Reducer
public struct WeeklyFeature {
  @ObservableState
  public struct State: Equatable {
    /// The screen lifecycle — the one source of truth (DECISIONS #1). No sibling `isLoading`/`error`
    /// bools; the enum is exhaustive. (`zones` + the fetch land in TASK-003, the `rhythm` child + the
    /// `selectedSection`/`isPlanCardExpanded` UI flags in TASK-004, and the 9.2/9.3 child slots as their
    /// phases land.)
    public var weeklyState: WeeklyViewState = .idle
    /// The persisted new-ISO-week watermark (DECISIONS #2) — the canonical `YYYY-Www` of the last week we
    /// successfully resolved a plan for. **Feature-local persisted state** (read by no other feature),
    /// using `@Shared(.appStorage)` purely as the TCA-native UserDefaults primitive — not a cross-feature
    /// reactive channel (so it sits outside §17.1's OPEN-1 gate; DECISIONS #2). Drives the "new week
    /// moment" + the freshness label; it never *gates* the fetch (the repo owns the cache, DECISIONS #4).
    ///
    /// Key is dotless (`weeklyLastSeenISOWeek`, not the plan's `weekly.lastSeenISOWeek`): swift-sharing
    /// rejects `.` for efficient key-value observation, and the dot was only namespacing cosmetics for a
    /// brand-new key with no prior persisted data — the watermark semantics are unchanged.
    @Shared(.appStorage("weeklyLastSeenISOWeek")) public var lastSeenISOWeek: String?

    public init() {}
  }

  public enum Action {
    /// Sent on tab appear (`task`/`onAppear`) — drives the get-or-cache fetch (TASK-003).
    case task
    /// Debounced manual refresh from `.ready` — forces a network regeneration (TASK-003).
    case refreshTapped
    /// Retry from the `.error` terminal — re-runs the fetch (TASK-003).
    case retryTapped
  }

  /// Cancellation namespace. `.weeklyFetch` owns the get-or-cache `.run` (`cancelInFlight`), `.refreshDebounce`
  /// the debounced refresh sleep — both declared now so TASK-003/004 don't reference an undefined case.
  public enum CancelID: Hashable, Sendable { case weeklyFetch, refreshDebounce }

  public init() {}

  public var body: some ReducerOf<Self> {
    // The fetch/orchestration effect lands in TASK-003; the shell is a no-op until then.
    Reduce { _, _ in .none }
  }
}

// MARK: - New-ISO-week detection (§17.2, DECISIONS #2/#3)

/// Format an `ISOWeek` as the canonical `YYYY-Www` string (zero-padded week, e.g. `2026-W03`). Mirrors
/// 4.2's `BriefRepositoryLive.isoWeekKey` so the feature's key byte-matches the server-stamped
/// `plan.isoWeek` (the post-fetch watermark round-trip holds); `CoachCore.ISOWeek` ships no `wireString`
/// and CoachCore stays out of scope, so this is a `WeeklyFeature`-local helper (DECISIONS #3).
func isoWeekKey(_ week: ISOWeek) -> String {
  String(format: "%04d-W%02d", week.year, week.week)
}

extension WeeklyFeature {
  /// The current Europe/Sofia ISO week as the canonical `YYYY-Www` — computed from `ISOWeek.current`,
  /// which reads the pinned `@Dependency(\.calendar)`/`(\.date)` (§17.2).
  var currentISOWeekKey: String { isoWeekKey(ISOWeek.current) }

  /// "New week" = the current key differs from the persisted watermark (a nil watermark is always new).
  /// Drives the §11 step-4 host trigger + the freshness moment — **not** the `refresh` flag of the appear
  /// call (which is always `false`, DECISIONS #4).
  func isNewWeek(_ state: State) -> Bool {
    currentISOWeekKey != (state.lastSeenISOWeek ?? "")
  }

  /// Record a just-resolved plan's ISO week as "seen" (DECISIONS #2) so subsequent opens the same week
  /// are not "new". Written on a successful `.ready` (exercised end-to-end in TASK-003).
  func recordSeenWeek(_ state: inout State, isoWeek: String) {
    state.$lastSeenISOWeek.withLock { $0 = isoWeek }
  }
}
