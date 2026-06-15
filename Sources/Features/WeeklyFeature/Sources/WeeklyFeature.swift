import BriefRepository
import ComposableArchitecture
import DomainModels

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
    /// bools; the enum is exhaustive. (The `@Shared` `lastSeenISOWeek` lands in TASK-002, `zones` + the
    /// fetch in TASK-003, the `rhythm` child + the `selectedSection`/`isPlanCardExpanded` UI flags in
    /// TASK-004, and the 9.2/9.3 child slots as their phases land.)
    public var weeklyState: WeeklyViewState = .idle

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
